import Foundation
import Observation

/// The catalog browse screen's state and intents (ProductSpecification § 4.1).
///
/// - Page 1 loads from the view's `.task` (`start()`), so it is cancelled with the view. Retry,
///   Reload and load-more come from taps and scrolling, so the view model owns those tasks
///   (`firstPageTask`, `pageTask`). They hold the view model weakly, also across the request, and
///   `deinit` cancels them: no request or event outlives the screen.
/// - Every page-1 request takes a new `generation`; a result whose generation is no longer
///   current is dropped (Architecture § 5).
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

    /// The current order. S3 makes it changeable.
    let sort: ProductSort = .defaultOrder
    /// One card per loaded product, in server order.
    private(set) var cards: [ProductCardModel] = []
    /// The page-1 load started by `retry()` or `reload()`; tests await it.
    @ObservationIgnored private(set) var firstPageTask: Task<Void, Never>?
    /// The latest page ≥ 2 load; tests await it.
    @ObservationIgnored private(set) var pageTask: Task<Void, Never>?

    private var list = CatalogListState()
    private var firstPage: FirstPageStatus = .notLoaded
    private var pageLoad: PageLoadStatus = .idle
    private var isRefreshing = false
    private var refreshError: AppError?
    private var generation = 0

    @ObservationIgnored private let repository: any ProductRepository
    @ObservationIgnored private let analytics: any AnalyticsTracking
    @ObservationIgnored private let clock: any Clock<Duration>

    private enum FirstPageStatus: Equatable {
        case notLoaded
        case loading
        case loaded
        case failed(AppError)
    }

    private enum PageLoadStatus: Equatable {
        case idle
        case loading
        case failed(AppError)
    }

    /// A page-1 request in flight: what finishing it needs.
    private struct FirstPageLoad {
        let trigger: CatalogLoadTrigger
        let generation: Int
        /// Restored if the request is cancelled.
        let previous: FirstPageStatus
        let hadVisibleContent: Bool
        let elapsed: () -> Duration
    }

    /// A page ≥ 2 request in flight.
    private struct PageLoad {
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
        pageTask?.cancel()
    }

    var phase: CatalogPhase {
        switch firstPage {
        case .notLoaded, .loading:
            .initialLoading
        case .failed(let error):
            .failed(error)
        case .loaded:
            list.isEmpty ? .empty : .content(footer: footer, refreshError: refreshError)
        }
    }

    private var footer: CatalogFooter {
        switch pageLoad {
        case .loading: .loading
        case .failed(let error): .failed(error)
        case .idle: list.canLoadMore ? .idle : .end
        }
    }

    // MARK: - Intents

    /// Loads page 1 unless it is loaded or loading. Called from the view's `.task`, which runs again
    /// on each appearance.
    func start() async {
        guard firstPage == .notLoaded else { return }
        await loadFirstPage(trigger: .initial)
    }

    /// The Catalog tab became visible (D-39).
    func catalogBecameVisible() {
        analytics.track(.catalogViewed(sort: sort, listContext: .browse))
    }

    /// The full-screen Retry after a failed first page.
    func retry() {
        guard case .failed(let error) = firstPage else { return }
        analytics.track(.retryRequested(failedSurface: .catalog, error: error))
        startFirstPageTask(trigger: .retry)
    }

    /// The empty state's Reload (D-38).
    func reload() {
        guard phase == .empty else { return }
        startFirstPageTask(trigger: .reload)
    }

    /// A card appeared on screen. Near the end of the list this loads the next page: one page
    /// request at a time, none past the end, and no automatic retry after a page failure.
    func itemAppeared(id: Product.ID) {
        guard
            firstPage == .loaded,
            pageLoad == .idle,
            !isRefreshing,
            list.canLoadMore,
            cards.suffix(Self.prefetchDistance).contains(where: { $0.id == id })
        else {
            return
        }
        startPageTask(isRetry: false)
    }

    /// The footer's Retry after a failed page. Ignored while a refresh is in flight: the refresh
    /// replaces the list, and only one page request may run at a time (D-41).
    func retryPage() {
        guard !isRefreshing, case .failed(let error) = pageLoad else { return }
        analytics.track(.retryRequested(failedSurface: .catalogPage, error: error))
        startPageTask(isRetry: true)
    }

    /// Pull-to-refresh: reloads page 1 without clearing visible content (AC-C5). A failure keeps the
    /// content and shows a banner. It cancels an in-flight page load and pauses load-more until it
    /// ends; it sends only `catalog_refreshed` (D-41).
    func refresh() async {
        guard firstPage == .loaded, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        refreshError = nil
        pageTask?.cancel()
        if pageLoad == .loading {
            pageLoad = .idle
        }
        generation += 1
        let generation = generation
        let elapsed = clock.stopwatch()

        do {
            let page = try await repository.products(sort: sort, skip: 0, limit: Self.pageSize)
            guard generation == self.generation else { return }
            list.replace(with: page)
            cards = list.items.map { ProductCardModel(product: $0) }
            pageLoad = .idle
            analytics.track(.catalogRefreshed(listContext: .browse, outcome: .success, durationMs: elapsed().wholeMilliseconds))
        } catch is CancellationError {
            return
        } catch {
            guard generation == self.generation else { return }
            let appError = error as? AppError ?? .unknown
            refreshError = appError
            analytics.track(.catalogRefreshed(listContext: .browse, outcome: .failure(appError), durationMs: elapsed().wholeMilliseconds))
        }
    }

    /// Closes the refresh-error banner.
    func dismissRefreshError() {
        refreshError = nil
    }

    // MARK: - Loading

    /// Page 1 from `start()`: structured, cancelled with the view's `.task`.
    private func loadFirstPage(trigger: CatalogLoadTrigger) async {
        let load = beginFirstPage(trigger: trigger)
        let result = await Self.fetch(from: repository, sort: sort, skip: 0)
        finishFirstPage(load, result: result)
    }

    /// Page 1 from a tap. The task captures the view model weakly and doesn't touch it during the
    /// request, so releasing the view model releases it and `deinit` cancels the request.
    private func startFirstPageTask(trigger: CatalogLoadTrigger) {
        let load = beginFirstPage(trigger: trigger)
        let repository = repository
        let sort = sort
        firstPageTask = Task { [weak self] in
            let result = await Self.fetch(from: repository, sort: sort, skip: 0)
            self?.finishFirstPage(load, result: result)
        }
    }

    private func beginFirstPage(trigger: CatalogLoadTrigger) -> FirstPageLoad {
        generation += 1
        let load = FirstPageLoad(
            trigger: trigger,
            generation: generation,
            previous: firstPage,
            hadVisibleContent: firstPage == .loaded && !list.isEmpty,
            elapsed: clock.stopwatch()
        )
        firstPage = .loading
        return load
    }

    private func finishFirstPage(_ load: FirstPageLoad, result: Result<ProductPage, any Error>) {
        guard load.generation == generation else { return }
        switch result {
        case .success(let page):
            list.replace(with: page)
            cards = list.items.map { ProductCardModel(product: $0) }
            firstPage = .loaded
            pageLoad = .idle
            let durationMs = load.elapsed().wholeMilliseconds
            Log.performance.info("catalog first page (\(load.trigger.rawValue, privacy: .public)) in \(durationMs, privacy: .public) ms")
            analytics.track(.catalogLoadCompleted(
                trigger: load.trigger,
                sort: sort,
                resultCount: list.items.count,
                totalCount: page.total,
                durationMs: durationMs
            ))
        case .failure(let error) where error is CancellationError:
            firstPage = load.previous
        case .failure(let error):
            let appError = error as? AppError ?? .unknown
            firstPage = .failed(appError)
            analytics.track(.catalogLoadFailed(trigger: load.trigger, sort: sort, error: appError, hasVisibleContent: load.hadVisibleContent))
        }
    }

    /// Starts loading the next page; `catalog_page_requested` marks the request's start. Like
    /// `startFirstPageTask`, the task doesn't keep the view model alive.
    private func startPageTask(isRetry: Bool) {
        pageLoad = .loading
        let load = PageLoad(index: list.pagesLoaded + 1, skip: list.nextSkip, generation: generation, elapsed: clock.stopwatch())
        analytics.track(.catalogPageRequested(listContext: .browse, pageIndex: load.index, sort: sort, isRetry: isRetry))
        let repository = repository
        let sort = sort
        pageTask = Task { [weak self] in
            let result = await Self.fetch(from: repository, sort: sort, skip: load.skip)
            self?.finishPage(load, result: result)
        }
    }

    private func finishPage(_ load: PageLoad, result: Result<ProductPage, any Error>) {
        guard load.generation == generation else { return }
        switch result {
        case .success(let page):
            let added = list.append(page)
            cards += list.items.suffix(added).map { ProductCardModel(product: $0) }
            pageLoad = .idle
            analytics.track(.catalogPageLoaded(
                listContext: .browse,
                pageIndex: load.index,
                itemCount: added,
                hasMore: list.canLoadMore,
                durationMs: load.elapsed().wholeMilliseconds
            ))
        case .failure(let error) where error is CancellationError:
            pageLoad = .idle
        case .failure(let error):
            let appError = error as? AppError ?? .unknown
            pageLoad = .failed(appError)
            analytics.track(.catalogPageFailed(listContext: .browse, pageIndex: load.index, error: appError))
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
