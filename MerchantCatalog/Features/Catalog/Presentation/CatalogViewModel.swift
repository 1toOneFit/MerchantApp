import Foundation
import Observation

/// The catalog browse screen's state and intents (ProductSpecification § 4.1).
///
/// - Page 1 loads from the view's `.task` (`start()`), so it is cancelled with the view. Retry,
///   Reload and load-more come from taps and scrolling, so the view model owns those tasks
///   (`firstPageTask`, the page tasks). They hold the view model weakly, also across the request,
///   and `deinit` cancels them: no request or event outlives the screen.
/// - Each list is a `CatalogFeed`. Every page-1 load stamps its feed with a new `generation`; a
///   result whose feed no longer has that generation is dropped (Architecture § 5).
/// - Cancellation is never an error: no state change, no event.
/// - Analytics go through `AnalyticsTracking` only; durations come from the injected monotonic
///   clock (D-40).
@MainActor
@Observable
final class CatalogViewModel {
    /// Products per request (ProductSpecification § 4.1).
    static let pageSize = 20
    /// The next page loads when one of the last this-many cards appears.
    static let prefetchDistance = 5

    /// The order of the list on screen.
    var sort: ProductSort { displayed.sort }
    /// Which list is on screen.
    var listContext: ListContext { .browse }
    /// What the list on screen shows.
    var phase: CatalogPhase { displayed.phase }
    /// One card per loaded product of the list on screen, in server order.
    var cards: [ProductCardModel] { displayed.cards }
    /// The page-1 load of the browse list started by a tap; tests await it.
    @ObservationIgnored private(set) var firstPageTask: Task<Void, Never>?
    /// The latest page ≥ 2 load of the list on screen; tests await it.
    var pageTask: Task<Void, Never>? { pageTasks[listContext] }

    private var browse = CatalogFeed(sort: .defaultOrder)
    private var isRefreshing = false
    /// Source of the feeds' generation stamps.
    private var generation = 0
    /// One page ≥ 2 load per list (D-52).
    @ObservationIgnored private var pageTasks: [ListContext: Task<Void, Never>] = [:]

    @ObservationIgnored private let repository: any ProductRepository
    @ObservationIgnored private let analytics: any AnalyticsTracking
    @ObservationIgnored private let clock: any Clock<Duration>

    /// A page-1 request in flight: what finishing it needs.
    private struct FirstPageLoad {
        let trigger: CatalogLoadTrigger
        let context: ListContext
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

    init(repository: any ProductRepository, analytics: any AnalyticsTracking, clock: any Clock<Duration> = ContinuousClock()) {
        self.repository = repository
        self.analytics = analytics
        self.clock = clock
    }

    /// Cancels the tasks the view model owns when the screen goes away.
    isolated deinit {
        firstPageTask?.cancel()
        for task in pageTasks.values {
            task.cancel()
        }
    }

    private var displayed: CatalogFeed { browse }

    // MARK: - Intents

    /// Loads the browse list's page 1 unless it is loaded or loading. Called from the view's
    /// `.task`, which runs again on each appearance.
    func start() async {
        guard browse.firstPage == .notLoaded else { return }
        await loadFirstPage(trigger: .initial)
    }

    /// The Catalog tab became visible (D-39).
    func catalogBecameVisible() {
        analytics.track(.catalogViewed(sort: sort, listContext: listContext))
    }

    /// The full-screen Retry after a failed first page.
    func retry() {
        guard case .failed(let error) = displayed.firstPage else { return }
        analytics.track(.retryRequested(failedSurface: .catalog, error: error))
        startFirstPageTask(trigger: .retry)
    }

    /// The empty state's Reload (D-38).
    func reload() {
        guard phase == .empty else { return }
        startFirstPageTask(trigger: .reload)
    }

    /// A card of the `context` list appeared on screen. Near the end of the list on screen this
    /// loads the next page: one page request at a time, none past the end, and no automatic retry
    /// after a page failure. Cards of a hidden list are ignored (D-52).
    func itemAppeared(id: Product.ID, in context: ListContext) {
        guard
            context == listContext,
            let feed = feed(for: context),
            feed.firstPage == .loaded,
            feed.pageLoad == .idle,
            !isRefreshing,
            feed.list.canLoadMore,
            feed.cards.suffix(Self.prefetchDistance).contains(where: { $0.id == id })
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
    /// pauses load-more until it ends; it sends only `catalog_refreshed` (D-41).
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

        let result = await Self.fetch(from: repository, sort: feed.sort, skip: 0)

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
        case .search: nil
        }
    }

    /// Changes the `context` feed in place, if it exists.
    @discardableResult
    private func update<Value>(_ context: ListContext, _ change: (inout CatalogFeed) -> Value) -> Value? {
        switch context {
        case .browse: change(&browse)
        case .search: nil
        }
    }

    // MARK: - Loading

    /// Page 1 from `start()`: structured, cancelled with the view's `.task`.
    private func loadFirstPage(trigger: CatalogLoadTrigger) async {
        let load = beginFirstPage(trigger: trigger)
        let result = await Self.fetch(from: repository, sort: load.sort, skip: 0)
        finishFirstPage(load, result: result)
    }

    /// Page 1 from a tap. The task captures the view model weakly and doesn't touch it during the
    /// request, so releasing the view model releases it and `deinit` cancels the request.
    private func startFirstPageTask(trigger: CatalogLoadTrigger) {
        firstPageTask?.cancel()
        let load = beginFirstPage(trigger: trigger)
        let repository = repository
        firstPageTask = Task { [weak self] in
            let result = await Self.fetch(from: repository, sort: load.sort, skip: 0)
            self?.finishFirstPage(load, result: result)
        }
    }

    private func beginFirstPage(trigger: CatalogLoadTrigger) -> FirstPageLoad {
        let context = ListContext.browse
        generation += 1
        pageTasks[context]?.cancel()
        let load = FirstPageLoad(
            trigger: trigger,
            context: context,
            sort: browse.sort,
            generation: generation,
            previous: browse.firstPage,
            hadVisibleContent: browse.hasVisibleContent,
            elapsed: clock.stopwatch()
        )
        browse.beginFirstPage(generation: generation)
        return load
    }

    private func finishFirstPage(_ load: FirstPageLoad, result: Result<ProductPage, any Error>) {
        guard feed(for: load.context)?.generation == load.generation else { return }
        switch result {
        case .success(let page):
            update(load.context) { $0.applyFirstPage(page) }
            let durationMs = load.elapsed().wholeMilliseconds
            Log.performance.info("catalog first page (\(load.trigger.rawValue, privacy: .public)) in \(durationMs, privacy: .public) ms")
            analytics.track(.catalogLoadCompleted(
                trigger: load.trigger,
                sort: load.sort,
                resultCount: feed(for: load.context)?.cards.count ?? 0,
                totalCount: page.total,
                durationMs: durationMs
            ))
        case .failure(let error) where error is CancellationError:
            update(load.context) { $0.firstPage = load.previous }
        case .failure(let error):
            let appError = error as? AppError ?? .unknown
            update(load.context) { $0.firstPage = .failed(appError) }
            analytics.track(.catalogLoadFailed(trigger: load.trigger, sort: load.sort, error: appError, hasVisibleContent: load.hadVisibleContent))
        }
    }

    /// Starts loading the next page of the `context` list; `catalog_page_requested` marks the
    /// request's start. Like `startFirstPageTask`, the task doesn't keep the view model alive.
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
        let sort = feed.sort
        pageTasks[context] = Task { [weak self] in
            let result = await Self.fetch(from: repository, sort: sort, skip: load.skip)
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

    /// One page request, without referencing the view model.
    private static func fetch(
        from repository: any ProductRepository,
        sort: ProductSort,
        skip: Int
    ) async -> Result<ProductPage, any Error> {
        do {
            return .success(try await repository.products(sort: sort, skip: skip, limit: pageSize))
        } catch {
            return .failure(error)
        }
    }
}
