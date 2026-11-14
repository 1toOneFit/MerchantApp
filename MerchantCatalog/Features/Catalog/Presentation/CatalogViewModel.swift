import Foundation
import Observation

/// The catalog screen's state and intents: browsing (ProductSpecification § 4.1) and search
/// (§ 4.2).
///
/// - Two lists, each a `CatalogFeed`: browse, and the results of the current query. The search list
///   is on screen while it exists; clearing the query drops it and shows browse again as it was,
///   without a request (AC-S4).
/// - Browse page 1 loads from the view's `.task` (`start()`), so it is cancelled with the view.
///   Everything else starts from a tap, a keystroke or scrolling, so the view model owns those tasks
///   (`firstPageTask`, `searchTask`, one page task per list, D-52). They hold the view model weakly,
///   also across the request, and `deinit` cancels them: no request or event outlives the screen.
/// - Search page 1 waits `searchDebounce` after the last change of the trimmed query, on the
///   injected clock. Every page-1 load stamps its feed with a new `generation`; a result whose feed
///   no longer has that generation, or no longer exists, is dropped (Architecture § 5).
/// - Needs attention (D-85) is a scope of the list on screen: it shows only the loaded products that
///   are low or out of stock, without a request of its own. In it, cards don't load pages as they
///   appear (the filtered list's end isn't the loaded list's end); `loadMoreTapped()` does.
/// - Cancellation is never an error: no state change, no event.
/// - Analytics go through `AnalyticsTracking` only, never with the query text (D-18); durations
///   come from the injected monotonic clock (D-40).
@MainActor
@Observable
final class CatalogViewModel {
    /// Products per request (ProductSpecification § 4.1).
    static let pageSize = 20
    /// The next page loads when one of the last this-many cards appears.
    static let prefetchDistance = 5
    /// Search waits this long after the last keystroke (ProductSpecification § 4.2).
    static let searchDebounce: Duration = .milliseconds(300)

    /// The search field's text, as typed.
    private(set) var searchText = ""
    /// The order of the list on screen.
    var sort: ProductSort { displayed.sort }
    /// Which list is on screen.
    var listContext: ListContext { displayed.context }
    /// What the list on screen shows.
    var phase: CatalogPhase { displayed.phase }
    /// The cards of the list on screen in the current scope, in server order.
    var cards: [ProductCardModel] { displayed.content(scope: scope).cards }
    /// The browse list, also while search results cover it (D-47).
    var browseList: CatalogListContent { browse.content(scope: scope) }
    /// The search results, while a query is committed.
    var searchList: CatalogListContent? { search?.content(scope: scope) }
    /// All products, or only those needing attention; applies to the list on screen (D-85).
    private(set) var scope: CatalogScope = .all
    /// Loaded products of the list on screen that are low or out of stock; `nil` until the list
    /// shows products.
    var attentionCount: Int? { displayed.hasVisibleContent ? displayed.attentionCount : nil }
    /// The page-1 load of the browse list started by a tap; tests await it.
    @ObservationIgnored private(set) var firstPageTask: Task<Void, Never>?
    /// The latest search page-1 load, including its debounce; tests await it.
    @ObservationIgnored private(set) var searchTask: Task<Void, Never>?
    /// The latest page ≥ 2 load of the list on screen; tests await it.
    var pageTask: Task<Void, Never>? { pageTasks[listContext] }

    private var browse: CatalogFeed
    private var search: CatalogFeed?
    private var isRefreshing = false
    /// Source of the feeds' generation stamps.
    private var generation = 0
    /// One page ≥ 2 load per list (D-52).
    @ObservationIgnored private var pageTasks: [ListContext: Task<Void, Never>] = [:]

    @ObservationIgnored private let repository: any ProductRepository
    @ObservationIgnored private let analytics: any AnalyticsTracking
    @ObservationIgnored private let clock: any Clock<Duration>
    /// The Catalog tab's router (D-53).
    @ObservationIgnored private let router: Router
    /// Shared with every screen; observed, so the cards' save state follows it (AC-V1).
    @ObservationIgnored private let savedProducts: SavedProductsStore
    /// `product_card_density_v1`: the cards' variant and the exposure report (D-70).
    @ObservationIgnored private let cardExperiment: CardExperiment

    /// Why a page 1 loads, and for which list.
    private enum FirstPageTrigger {
        case browse(CatalogLoadTrigger)
        case search(SearchQuery, SearchTrigger)

        var context: ListContext {
            switch self {
            case .browse: .browse
            case .search: .search
            }
        }

        var logName: String {
            switch self {
            case .browse(let trigger): "catalog first page (\(trigger.rawValue))"
            case .search(_, let trigger): "search first page (\(trigger.rawValue))"
            }
        }
    }

    /// A page-1 request in flight: what finishing it needs.
    private struct FirstPageLoad {
        let trigger: FirstPageTrigger
        let sort: ProductSort
        let generation: Int
        /// Restored if the request is cancelled.
        let previous: CatalogFeed.FirstPageStatus
        let hadVisibleContent: Bool
        let elapsed: () -> Duration
    }

    /// A page ≥ 2 request in flight.
    private struct PageLoad {
        let context: ListContext
        let index: Int
        let skip: Int
        let generation: Int
        let elapsed: () -> Duration
    }

    init(
        repository: any ProductRepository,
        analytics: any AnalyticsTracking,
        router: Router,
        savedProducts: SavedProductsStore,
        cardExperiment: CardExperiment,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.repository = repository
        self.analytics = analytics
        self.router = router
        self.savedProducts = savedProducts
        self.cardExperiment = cardExperiment
        self.clock = clock
        browse = CatalogFeed(query: nil, sort: .defaultOrder, cardVariant: cardExperiment.variant)
    }

    /// Cancels the tasks the view model owns when the screen goes away.
    isolated deinit {
        firstPageTask?.cancel()
        searchTask?.cancel()
        for task in pageTasks.values {
            task.cancel()
        }
    }

    private var displayed: CatalogFeed { search ?? browse }

    // MARK: - Intents

    /// Loads the browse list's page 1 unless it is loaded or loading. Called from the view's
    /// `.task`, which runs again on each appearance.
    func start() async {
        guard browse.firstPage == .notLoaded else { return }
        let load = beginFirstPage(.browse(.initial))
        let result = await Self.fetch(from: repository, query: nil, sort: load.sort, skip: 0)
        finishFirstPage(load, result: result)
    }

    /// The Catalog tab became visible (D-39).
    func catalogBecameVisible() {
        analytics.track(.catalogViewed(sort: sort, listContext: listContext))
    }

    /// The full-screen Retry after a failed first page of the list on screen.
    func retry() {
        guard case .failed(let error) = displayed.firstPage else { return }
        if let query = search?.query {
            analytics.track(.retryRequested(failedSurface: .search, error: error))
            startSearchLoad(query, trigger: .retry)
        } else {
            analytics.track(.retryRequested(failedSurface: .catalog, error: error))
            startBrowseLoad(trigger: .retry)
        }
    }

    /// The browse empty state's Reload (D-38).
    func reload() {
        guard phase == .empty else { return }
        startBrowseLoad(trigger: .reload)
    }

    /// The search field's text changed. A new trimmed query is searched once typing pauses for
    /// `searchDebounce`; an empty one returns to browse at once (D-49, D-50).
    func searchTextChanged(to text: String) {
        let previousQuery = SearchQuery(searchText)
        searchText = text
        let query = SearchQuery(text)
        guard query != previousQuery else { return }

        guard let query else {
            if let previousQuery {
                endSearch(lastQuery: previousQuery)
            }
            return
        }
        if previousQuery == nil {
            analytics.track(.searchStarted(sort: sort))
        }
        scheduleSearch(query)
    }

    /// The no-results state's Clear search.
    func clearSearch() {
        searchTextChanged(to: "")
    }

    /// The search field was dismissed (Cancel): the query is cleared and browse returns. The system
    /// may also empty the field's text, before or after; that second change is a no-op.
    ///
    /// Ignored while details are pushed on the Catalog tab: if the system deactivated the field for
    /// the push, going back must still show the search (AC-C6, D-54).
    func searchDismissed() {
        guard router.path.isEmpty else {
            Log.navigation.debug("search dismissal ignored while details are open")
            return
        }
        searchTextChanged(to: "")
    }

    /// The sort menu's selection. Another sort reloads page 1 of the list on screen in that order,
    /// on the server; while searching it changes only the search's sort (D-45, D-46).
    func sortSelected(_ newSort: ProductSort) {
        guard newSort != sort else { return }
        analytics.track(.sortChanged(from: sort, to: newSort, listContext: listContext))
        if let query = search?.query {
            search?.sort = newSort
            startSearchLoad(query, trigger: .sortChange)
        } else {
            browse.sort = newSort
            startBrowseLoad(trigger: .sortChange)
        }
    }

    /// A card of the `context` list appeared on screen: it reports experiment exposure (D-70), and
    /// near the end of the list it loads the next page: one page request at a time, none past the
    /// end, and no automatic retry after a page failure. Cards of a hidden list are ignored (D-52);
    /// in Needs attention no page loads this way (D-85).
    func itemAppeared(id: Product.ID, in context: ListContext) {
        guard context == listContext, let feed = feed(for: context), feed.firstPage == .loaded else {
            return
        }
        cardExperiment.cardRendered(in: context)
        guard
            scope == .all,
            feed.pageLoad == .idle,
            !isRefreshing,
            feed.list.canLoadMore,
            feed.cards.suffix(Self.prefetchDistance).contains(where: { $0.id == id })
        else {
            return
        }
        startPageTask(in: context, isRetry: false)
    }

    /// A card of the `context` list was tapped: `product_selected` from the list on screen, then the
    /// details screen on the Catalog tab's stack (D-53). `position` counts the cards on screen: in
    /// Needs attention, the filtered list (D-85). Cards of a hidden list, or outside the scope, are
    /// ignored (D-47).
    func cardSelected(id: Product.ID, in context: ListContext) {
        guard
            context == listContext,
            let feed = feed(for: context),
            let position = feed.cards(in: scope).firstIndex(where: { $0.id == id })
        else {
            return
        }
        let source: ProductSource = context == .search ? .search : .catalog
        analytics.track(.productSelected(productID: id, source: source, position: position, sort: feed.sort))
        router.showProductDetail(ProductDetailRoute(productID: id, source: source))
    }

    /// Whether the card's product is saved.
    func isSaved(_ id: Product.ID) -> Bool {
        savedProducts.isSaved(id)
    }

    /// A card's save button in the `context` list: saves or removes the loaded product and reports it
    /// from the list on screen (surface, and the position among the cards on screen, D-85). Buttons
    /// of a hidden list, or outside the scope, are ignored (D-47).
    func saveToggled(id: Product.ID, in context: ListContext) {
        guard
            context == listContext,
            let feed = feed(for: context),
            let position = feed.cards(in: scope).firstIndex(where: { $0.id == id }),
            let product = feed.list.items.first(where: { $0.id == id })
        else {
            return
        }
        let change = savedProducts.isSaved(id)
            ? savedProducts.remove(id: id)
            : savedProducts.save(product)
        guard let change else { return }
        let surface: SaveSurface = context == .search ? .searchCard : .catalogCard
        analytics.track(change.event(surface: surface, position: position))
    }

    /// The All products / Needs attention control (D-85). Only what the grid shows changes: no
    /// request, and the lists keep their pages.
    func scopeSelected(_ newScope: CatalogScope) {
        guard newScope != scope else { return }
        scope = newScope
    }

    /// Needs attention's "Load more products": the next page of the list on screen, so the scope
    /// can look at more products (D-85). One page request at a time, none past the end, none during
    /// a refresh, none after a page failure (that is the footer's Retry).
    func loadMoreTapped() {
        let context = listContext
        guard
            let feed = feed(for: context),
            feed.firstPage == .loaded,
            feed.pageLoad == .idle,
            !isRefreshing,
            feed.list.canLoadMore
        else {
            return
        }
        startPageTask(in: context, isRetry: false)
    }

    /// The footer's Retry after a failed page. Ignored while a refresh is in flight: the refresh
    /// replaces the list, and only one page request may run at a time (D-41).
    func retryPage() {
        guard !isRefreshing, case .failed(let error) = displayed.pageLoad else { return }
        analytics.track(.retryRequested(failedSurface: .catalogPage, error: error))
        startPageTask(in: listContext, isRetry: true)
    }

    /// Pull-to-refresh: reloads page 1 of the list on screen without clearing visible content
    /// (AC-C5). A failure keeps the content and shows a banner. It cancels an in-flight page load and
    /// pauses load-more until it ends; it sends only `catalog_refreshed` (D-41, D-48).
    func refresh() async {
        let context = listContext
        guard let feed = feed(for: context), feed.firstPage == .loaded, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        pageTasks[context]?.cancel()
        generation += 1
        let generation = generation
        update(context) { $0.beginRefresh(generation: generation) }
        let elapsed = clock.stopwatch()

        let result = await Self.fetch(from: repository, query: feed.query, sort: feed.sort, skip: 0)

        guard self.feed(for: context)?.generation == generation else { return }
        switch result {
        case .success(let page):
            update(context) { $0.applyFirstPage(page) }
            analytics.track(.catalogRefreshed(listContext: context, outcome: .success, durationMs: elapsed().wholeMilliseconds))
        case .failure(let error) where error is CancellationError:
            return
        case .failure(let error):
            let appError = error as? AppError ?? .unknown
            update(context) { $0.refreshError = appError }
            analytics.track(.catalogRefreshed(listContext: context, outcome: .failure(appError), durationMs: elapsed().wholeMilliseconds))
        }
    }

    /// Closes the refresh-error banner.
    func dismissRefreshError() {
        update(listContext) { $0.refreshError = nil }
    }

    // MARK: - Feeds

    private func feed(for context: ListContext) -> CatalogFeed? {
        switch context {
        case .browse: browse
        case .search: search
        }
    }

    /// Changes the `context` feed in place, if it exists.
    @discardableResult
    private func update<Value>(_ context: ListContext, _ change: (inout CatalogFeed) -> Value) -> Value? {
        switch context {
        case .browse:
            return change(&browse)
        case .search:
            guard search != nil else { return nil }
            return change(&search!)
        }
    }

    // MARK: - Search

    /// Searches `query` after the debounce. A newer keystroke cancels the task: during the sleep
    /// nothing has happened yet; after it, the request is cancelled and its result dropped.
    private func scheduleSearch(_ query: SearchQuery) {
        searchTask?.cancel()
        let repository = repository
        let clock = clock
        searchTask = Task { [weak self] in
            do {
                try await clock.sleep(for: Self.searchDebounce)
            } catch {
                return
            }
            // The sleep may have ended just before a newer keystroke cancelled this task.
            guard !Task.isCancelled, let load = self?.beginSearch(query) else { return }
            let result = await Self.fetch(from: repository, query: query, sort: load.sort, skip: 0)
            self?.finishFirstPage(load, result: result)
        }
    }

    /// A committed query gets a new search feed, in the sort on screen (D-46).
    private func beginSearch(_ query: SearchQuery) -> FirstPageLoad {
        search = CatalogFeed(query: query, sort: sort, cardVariant: cardExperiment.variant)
        return beginFirstPage(.search(query, .typing))
    }

    /// Search page 1 without the debounce (Retry, sort change).
    private func startSearchLoad(_ query: SearchQuery, trigger: SearchTrigger) {
        searchTask?.cancel()
        let load = beginFirstPage(.search(query, trigger))
        let repository = repository
        searchTask = Task { [weak self] in
            let result = await Self.fetch(from: repository, query: query, sort: load.sort, skip: 0)
            self?.finishFirstPage(load, result: result)
        }
    }

    /// The query became empty: browse is on screen again, as it was.
    private func endSearch(lastQuery: SearchQuery) {
        searchTask?.cancel()
        searchTask = nil
        pageTasks[.search]?.cancel()
        pageTasks[.search] = nil
        let hadResults = search?.hasVisibleContent ?? false
        search = nil
        analytics.track(.searchCleared(queryLength: lastQuery.length, hadResults: hadResults))
    }

    // MARK: - Loading

    /// Browse page 1 from a tap. The task captures the view model weakly and doesn't touch it during
    /// the request, so releasing the view model releases it and `deinit` cancels the request.
    private func startBrowseLoad(trigger: CatalogLoadTrigger) {
        firstPageTask?.cancel()
        let load = beginFirstPage(.browse(trigger))
        let repository = repository
        firstPageTask = Task { [weak self] in
            let result = await Self.fetch(from: repository, query: nil, sort: load.sort, skip: 0)
            self?.finishFirstPage(load, result: result)
        }
    }

    /// Stamps the trigger's feed with a new generation and shows its skeleton. A page load of the
    /// list in flight is cancelled; its result would be stale anyway.
    private func beginFirstPage(_ trigger: FirstPageTrigger) -> FirstPageLoad {
        let context = trigger.context
        generation += 1
        let generation = generation
        pageTasks[context]?.cancel()
        let feed = feed(for: context)
        let load = FirstPageLoad(
            trigger: trigger,
            sort: feed?.sort ?? sort,
            generation: generation,
            previous: feed?.firstPage ?? .notLoaded,
            hadVisibleContent: feed?.hasVisibleContent ?? false,
            elapsed: clock.stopwatch()
        )
        update(context) { $0.beginFirstPage(generation: generation) }
        return load
    }

    private func finishFirstPage(_ load: FirstPageLoad, result: Result<ProductPage, any Error>) {
        let context = load.trigger.context
        guard feed(for: context)?.generation == load.generation else { return }
        switch result {
        case .success(let page):
            update(context) { $0.applyFirstPage(page) }
            let resultCount = feed(for: context)?.cards.count ?? 0
            let durationMs = load.elapsed().wholeMilliseconds
            Log.performance.info("\(load.trigger.logName, privacy: .public) in \(durationMs, privacy: .public) ms")
            switch load.trigger {
            case .browse(let trigger):
                analytics.track(.catalogLoadCompleted(
                    trigger: trigger,
                    sort: load.sort,
                    resultCount: resultCount,
                    totalCount: page.total,
                    durationMs: durationMs
                ))
            case .search(let query, let trigger):
                analytics.track(.searchPerformed(
                    trigger: trigger,
                    queryLength: query.length,
                    wordCount: query.wordCount,
                    sort: load.sort,
                    resultCount: resultCount,
                    totalCount: page.total,
                    durationMs: durationMs
                ))
            }
        case .failure(let error) where error is CancellationError:
            update(context) { $0.firstPage = load.previous }
        case .failure(let error):
            let appError = error as? AppError ?? .unknown
            update(context) { $0.firstPage = .failed(appError) }
            switch load.trigger {
            case .browse(let trigger):
                analytics.track(.catalogLoadFailed(trigger: trigger, sort: load.sort, error: appError, hasVisibleContent: load.hadVisibleContent))
            case .search(let query, let trigger):
                analytics.track(.searchFailed(trigger: trigger, queryLength: query.length, error: appError))
            }
        }
    }

    /// Starts loading the next page of the `context` list; `catalog_page_requested` marks the
    /// request's start. Like the page-1 tasks, the task doesn't keep the view model alive.
    private func startPageTask(in context: ListContext, isRetry: Bool) {
        guard let feed = feed(for: context) else { return }
        update(context) { $0.pageLoad = .loading }
        let load = PageLoad(
            context: context,
            index: feed.list.pagesLoaded + 1,
            skip: feed.list.nextSkip,
            generation: feed.generation,
            elapsed: clock.stopwatch()
        )
        analytics.track(.catalogPageRequested(listContext: context, pageIndex: load.index, sort: feed.sort, isRetry: isRetry))
        let repository = repository
        pageTasks[context] = Task { [weak self] in
            let result = await Self.fetch(from: repository, query: feed.query, sort: feed.sort, skip: load.skip)
            self?.finishPage(load, result: result)
        }
    }

    private func finishPage(_ load: PageLoad, result: Result<ProductPage, any Error>) {
        guard feed(for: load.context)?.generation == load.generation else { return }
        switch result {
        case .success(let page):
            let added = update(load.context) { $0.appendPage(page) } ?? 0
            analytics.track(.catalogPageLoaded(
                listContext: load.context,
                pageIndex: load.index,
                itemCount: added,
                hasMore: feed(for: load.context)?.list.canLoadMore ?? false,
                durationMs: load.elapsed().wholeMilliseconds
            ))
        case .failure(let error) where error is CancellationError:
            update(load.context) { $0.pageLoad = .idle }
        case .failure(let error):
            let appError = error as? AppError ?? .unknown
            update(load.context) { $0.pageLoad = .failed(appError) }
            analytics.track(.catalogPageFailed(listContext: load.context, pageIndex: load.index, error: appError))
        }
    }

    /// One page of the catalog (`query == nil`) or of search results, without referencing the view
    /// model.
    private static func fetch(
        from repository: any ProductRepository,
        query: SearchQuery?,
        sort: ProductSort,
        skip: Int
    ) async -> Result<ProductPage, any Error> {
        do {
            if let query {
                return .success(try await repository.search(query: query.text, sort: sort, skip: skip, limit: pageSize))
            }
            return .success(try await repository.products(sort: sort, skip: skip, limit: pageSize))
        } catch {
            return .failure(error)
        }
    }
}
