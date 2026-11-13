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

    private var list = CatalogListState()
    private var firstPage: FirstPageStatus = .notLoaded
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
            list.isEmpty ? .empty : .content(footer: footer, refreshError: nil)
        }
    }

    private var footer: CatalogFooter {
        list.canLoadMore ? .idle : .end
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
}
