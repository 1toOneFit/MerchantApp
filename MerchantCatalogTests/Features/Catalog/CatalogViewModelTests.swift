import Testing
@testable import MerchantCatalog

/// Catalog browse behavior (ProductSpecification § 4.1, AC-C1–AC-C5) and its analytics
/// (Analytics.md § 3 Catalog, Reliability), driven through view-model intents with a controllable
/// repository and clock.
@MainActor
struct CatalogViewModelTests {
    private let repository = FakeProductRepository()
    private let analytics = SpyAnalytics()
    private let clock = TestClock()

    private func makeViewModel() -> CatalogViewModel {
        CatalogViewModel(repository: repository, analytics: analytics, clock: clock)
    }

    private func advanceClockOnEachRequest(by duration: Duration) {
        repository.onRequest = { [clock] in clock.advance(by: duration) }
    }

    // MARK: - First page

    @Test func startsInInitialLoading() {
        let viewModel = makeViewModel()

        #expect(viewModel.phase == .initialLoading)
        #expect(viewModel.cards.isEmpty)
        #expect(repository.requests.isEmpty)
        #expect(analytics.events.isEmpty)
    }

    /// AC-C1: launch → skeleton → a grid of 20 products without user action.
    @Test func startLoadsFirstPage() async {
        repository.enqueue(page(1...20, total: 194, skip: 0))
        advanceClockOnEachRequest(by: .milliseconds(250))
        let viewModel = makeViewModel()

        await viewModel.start()

        #expect(repository.requests == [.init(sort: .defaultOrder, skip: 0, limit: 20)])
        #expect(viewModel.cards.map(\.id) == Array(1...20))
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(analytics.events == [
            .catalogLoadCompleted(trigger: .initial, sort: .defaultOrder, resultCount: 20, totalCount: 194, durationMs: 250),
        ])
    }

    @Test func startFailureShowsError() async {
        repository.enqueue(failure: AppError.offline)
        let viewModel = makeViewModel()

        await viewModel.start()

        #expect(viewModel.phase == .failed(.offline))
        #expect(viewModel.cards.isEmpty)
        #expect(analytics.events == [
            .catalogLoadFailed(trigger: .initial, sort: .defaultOrder, error: .offline, hasVisibleContent: false),
        ])
    }

    @Test func unexpectedErrorsAreUnknown() async {
        struct Unexpected: Error {}
        repository.enqueue(failure: Unexpected())
        let viewModel = makeViewModel()

        await viewModel.start()

        #expect(viewModel.phase == .failed(.unknown))
    }

    /// AC-C3: the offline error with Retry; Retry loads the grid.
    @Test func retryAfterFailureLoadsContent() async {
        repository.enqueue(failure: AppError.offline)
        repository.enqueue(page(1...20, total: 194, skip: 0))
        let viewModel = makeViewModel()
        await viewModel.start()

        viewModel.retry()
        await viewModel.firstPageTask?.value

        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(viewModel.cards.count == 20)
        #expect(analytics.events == [
            .catalogLoadFailed(trigger: .initial, sort: .defaultOrder, error: .offline, hasVisibleContent: false),
            .retryRequested(failedSurface: .catalog, error: .offline),
            .catalogLoadCompleted(trigger: .retry, sort: .defaultOrder, resultCount: 20, totalCount: 194, durationMs: 0),
        ])
    }

    @Test func retryShowsSkeletonWhileLoading() async {
        repository.enqueue(failure: AppError.timeout)
        let viewModel = makeViewModel()
        await viewModel.start()

        viewModel.retry()
        await repository.waitForPendingRequests(1)

        #expect(viewModel.phase == .initialLoading)
        await viewModel.start()
        #expect(repository.requests.count == 2, "start() during a retry must not request again")

        repository.resumeNext(with: .success(page(1...20, total: 194, skip: 0)))
        await viewModel.firstPageTask?.value
        #expect(viewModel.cards.count == 20)
    }

    @Test func emptyResponseShowsEmpty() async {
        repository.enqueue(emptyPage(total: 0, skip: 0))
        let viewModel = makeViewModel()

        await viewModel.start()

        #expect(viewModel.phase == .empty)
        #expect(analytics.events == [
            .catalogLoadCompleted(trigger: .initial, sort: .defaultOrder, resultCount: 0, totalCount: 0, durationMs: 0),
        ])
    }

    /// D-38: Reload after an empty response is not a retry of a failure.
    @Test func reloadFromEmptyUsesReloadTrigger() async {
        repository.enqueue(emptyPage(total: 0, skip: 0))
        repository.enqueue(page(1...20, total: 194, skip: 0))
        let viewModel = makeViewModel()
        await viewModel.start()

        viewModel.reload()
        await viewModel.firstPageTask?.value

        #expect(viewModel.cards.count == 20)
        #expect(analytics.events.last == .catalogLoadCompleted(
            trigger: .reload, sort: .defaultOrder, resultCount: 20, totalCount: 194, durationMs: 0
        ))
        #expect(!analytics.events.contains { $0.name == .retryRequested })
    }

    /// Switching tabs cancels the view's `.task`: no failure UI or event, and the next appearance
    /// loads again.
    @Test func cancelledStartLeavesSkeletonAndRestarts() async {
        repository.enqueue(failure: CancellationError())
        repository.enqueue(page(1...20, total: 194, skip: 0))
        let viewModel = makeViewModel()

        await viewModel.start()

        #expect(viewModel.phase == .initialLoading)
        #expect(analytics.events.isEmpty)

        await viewModel.start()

        #expect(viewModel.cards.count == 20)
        #expect(repository.requests.count == 2)
    }

    /// Returning to the tab (or popping back) re-runs `.task`; loaded content is kept.
    @Test func startAfterContentDoesNothing() async {
        repository.enqueue(page(1...20, total: 194, skip: 0))
        let viewModel = makeViewModel()

        await viewModel.start()
        await viewModel.start()

        #expect(repository.requests.count == 1)
    }

    // MARK: - catalog_viewed

    @Test func catalogBecameVisibleTracksView() {
        let viewModel = makeViewModel()

        viewModel.catalogBecameVisible()
        viewModel.catalogBecameVisible()

        #expect(analytics.events == [
            .catalogViewed(sort: .defaultOrder, listContext: .browse),
            .catalogViewed(sort: .defaultOrder, listContext: .browse),
        ])
    }
}
