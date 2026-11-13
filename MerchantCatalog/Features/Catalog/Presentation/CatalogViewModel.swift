import Foundation
import Observation

/// The catalog browse screen's state and intents (ProductSpecification § 4.1).
///
/// - Page 1 loads from the view's `.task` (`start()`), so it is cancelled with the view; Retry and
///   Reload start a task the view model owns (`firstPageTask`).
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
    private(set) var firstPageTask: Task<Void, Never>?
    /// The latest page ≥ 2 load; tests await it.
    private(set) var pageTask: Task<Void, Never>?

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

    init(repository: any ProductRepository, analytics: any AnalyticsTracking, clock: any Clock<Duration> = ContinuousClock()) {
        self.repository = repository
        self.analytics = analytics
        self.clock = clock
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

    private func startFirstPageTask(trigger: CatalogLoadTrigger) {
        firstPageTask = Task { [weak self] in
            await self?.loadFirstPage(trigger: trigger)
        }
    }

    private func loadFirstPage(trigger: CatalogLoadTrigger) async {
        generation += 1
        let generation = generation
        let previous = firstPage
        let hadVisibleContent = previous == .loaded && !list.isEmpty
        firstPage = .loading
        let elapsed = clock.stopwatch()

        do {
            let page = try await repository.products(sort: sort, skip: 0, limit: Self.pageSize)
            guard generation == self.generation else { return }
            list.replace(with: page)
            cards = list.items.map { ProductCardModel(product: $0) }
            firstPage = .loaded
            pageLoad = .idle
            let durationMs = elapsed().wholeMilliseconds
            Log.performance.info("catalog first page (\(trigger.rawValue, privacy: .public)) in \(durationMs, privacy: .public) ms")
            analytics.track(.catalogLoadCompleted(
                trigger: trigger,
                sort: sort,
                resultCount: list.items.count,
                totalCount: page.total,
                durationMs: durationMs
            ))
        } catch is CancellationError {
            guard generation == self.generation else { return }
            firstPage = previous
        } catch {
            guard generation == self.generation else { return }
            let appError = error as? AppError ?? .unknown
            firstPage = .failed(appError)
            analytics.track(.catalogLoadFailed(trigger: trigger, sort: sort, error: appError, hasVisibleContent: hadVisibleContent))
        }
    }

    /// Starts loading the next page; `catalog_page_requested` marks the request's start.
    private func startPageTask(isRetry: Bool) {
        pageLoad = .loading
        let pageIndex = list.pagesLoaded + 1
        let skip = list.nextSkip
        let generation = generation
        analytics.track(.catalogPageRequested(listContext: .browse, pageIndex: pageIndex, sort: sort, isRetry: isRetry))
        pageTask = Task { [weak self] in
            await self?.loadPage(index: pageIndex, skip: skip, generation: generation)
        }
    }

    private func loadPage(index: Int, skip: Int, generation: Int) async {
        let elapsed = clock.stopwatch()
        do {
            let page = try await repository.products(sort: sort, skip: skip, limit: Self.pageSize)
            guard generation == self.generation else { return }
            let added = list.append(page)
            cards += list.items.suffix(added).map { ProductCardModel(product: $0) }
            pageLoad = .idle
            analytics.track(.catalogPageLoaded(
                listContext: .browse,
                pageIndex: index,
                itemCount: added,
                hasMore: list.canLoadMore,
                durationMs: elapsed().wholeMilliseconds
            ))
        } catch is CancellationError {
            guard generation == self.generation else { return }
            pageLoad = .idle
        } catch {
            guard generation == self.generation else { return }
            let appError = error as? AppError ?? .unknown
            pageLoad = .failed(appError)
            analytics.track(.catalogPageFailed(listContext: .browse, pageIndex: index, error: appError))
        }
    }
}
