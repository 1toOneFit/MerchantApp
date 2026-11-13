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

    /// A view model showing products 1...20 of `total`, with the analytics so far cleared.
    private func loadedViewModel(total: Int = 194) async -> CatalogViewModel {
        repository.enqueue(page(1...20, total: total, skip: 0))
        let viewModel = makeViewModel()
        await viewModel.start()
        analytics.reset()
        return viewModel
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

    // MARK: - Pagination

    @Test func nearEndLoadsNextPage() async {
        let viewModel = await loadedViewModel()
        advanceClockOnEachRequest(by: .milliseconds(80))
        repository.enqueue(page(21...40, total: 194, skip: 20))

        viewModel.itemAppeared(id: 15)
        #expect(repository.requests.count == 1, "15 is not among the last 5 cards")

        viewModel.itemAppeared(id: 16)
        await viewModel.pageTask?.value

        #expect(repository.requests.last == .init(sort: .defaultOrder, skip: 20, limit: 20))
        #expect(viewModel.cards.map(\.id) == Array(1...40))
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(analytics.events == [
            .catalogPageRequested(listContext: .browse, pageIndex: 2, sort: .defaultOrder, isRetry: false),
            .catalogPageLoaded(listContext: .browse, pageIndex: 2, itemCount: 20, hasMore: true, durationMs: 80),
        ])
    }

    @Test func itemAppearedBeforeContentDoesNothing() async {
        repository.enqueue(failure: AppError.offline)
        let viewModel = makeViewModel()

        viewModel.itemAppeared(id: 1)
        await viewModel.start()
        viewModel.itemAppeared(id: 1)

        #expect(repository.requests.count == 1)
    }

    @Test func loadMoreIsSingleFlight() async {
        let viewModel = await loadedViewModel()

        viewModel.itemAppeared(id: 20)
        await repository.waitForPendingRequests(1)
        #expect(viewModel.phase == .content(footer: .loading, refreshError: nil))

        viewModel.itemAppeared(id: 19)
        viewModel.itemAppeared(id: 20)
        #expect(repository.requests.count == 2)
        #expect(analytics.events.filter { $0.name == .catalogPageRequested }.count == 1)

        repository.resumeNext(with: .success(page(21...40, total: 194, skip: 20)))
        await viewModel.pageTask?.value
        #expect(viewModel.cards.count == 40)
    }

    /// AC-C4 (first half): a failed page 2 keeps page 1 and shows the inline retry footer.
    @Test func pageFailureKeepsContent() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(failure: AppError.timeout)

        viewModel.itemAppeared(id: 20)
        await viewModel.pageTask?.value

        #expect(viewModel.cards.count == 20)
        #expect(viewModel.phase == .content(footer: .failed(.timeout), refreshError: nil))
        #expect(analytics.events.last == .catalogPageFailed(listContext: .browse, pageIndex: 2, error: .timeout))

        viewModel.itemAppeared(id: 20)
        #expect(repository.requests.count == 2, "no automatic retry; the footer has a Retry button")
    }

    /// AC-C4 (second half): Retry appends page 2.
    @Test func retryPageAppends() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(failure: AppError.timeout)
        viewModel.itemAppeared(id: 20)
        await viewModel.pageTask?.value
        repository.enqueue(page(21...40, total: 194, skip: 20))

        viewModel.retryPage()
        await viewModel.pageTask?.value

        #expect(viewModel.cards.map(\.id) == Array(1...40))
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(Array(analytics.events.suffix(3)) == [
            .retryRequested(failedSurface: .catalogPage, error: .timeout),
            .catalogPageRequested(listContext: .browse, pageIndex: 2, sort: .defaultOrder, isRetry: true),
            .catalogPageLoaded(listContext: .browse, pageIndex: 2, itemCount: 20, hasMore: true, durationMs: 0),
        ])
    }

    @Test func noRequestPastTheEnd() async {
        let viewModel = await loadedViewModel(total: 45)
        repository.enqueue(page(21...40, total: 45, skip: 20))
        repository.enqueue(page(41...45, total: 45, skip: 40))

        viewModel.itemAppeared(id: 20)
        await viewModel.pageTask?.value
        viewModel.itemAppeared(id: 40)
        await viewModel.pageTask?.value

        #expect(viewModel.cards.count == 45)
        #expect(viewModel.phase == .content(footer: .end, refreshError: nil))
        #expect(analytics.events.last == .catalogPageLoaded(listContext: .browse, pageIndex: 3, itemCount: 5, hasMore: false, durationMs: 0))

        viewModel.itemAppeared(id: 45)
        #expect(repository.requests.count == 3)
    }

    @Test func duplicateIDsAreDropped() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(page(19...38, total: 194, skip: 20))

        viewModel.itemAppeared(id: 20)
        await viewModel.pageTask?.value

        #expect(viewModel.cards.map(\.id) == Array(1...38))
        #expect(analytics.events.last == .catalogPageLoaded(listContext: .browse, pageIndex: 2, itemCount: 18, hasMore: true, durationMs: 0))
    }

    /// AC-C2: scrolling to the end shows all 194 products once and stops requesting.
    @Test func loadsWholeCatalogWithoutDuplicates() async {
        let viewModel = await loadedViewModel(total: 194)

        for start in stride(from: 21, through: 194, by: 20) {
            repository.enqueue(page(start...min(start + 19, 194), total: 194, skip: start - 1))
            viewModel.itemAppeared(id: start - 1)
            await viewModel.pageTask?.value
        }
        viewModel.itemAppeared(id: 194)

        #expect(viewModel.cards.map(\.id) == Array(1...194))
        #expect(viewModel.phase == .content(footer: .end, refreshError: nil))
        #expect(repository.requests.map(\.skip) == Array(stride(from: 0, through: 180, by: 20)))
    }

    @Test func cancelledPageLoadSendsNothing() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(failure: CancellationError())

        viewModel.itemAppeared(id: 20)
        await viewModel.pageTask?.value

        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(analytics.events.map(\.name) == [.catalogPageRequested])
    }

    // MARK: - Pull-to-refresh

    @Test func refreshReplacesContent() async {
        let viewModel = await loadedViewModel()
        advanceClockOnEachRequest(by: .milliseconds(120))
        repository.enqueue(page(101...120, total: 150, skip: 0))

        await viewModel.refresh()

        #expect(repository.requests.last == .init(sort: .defaultOrder, skip: 0, limit: 20))
        #expect(viewModel.cards.map(\.id) == Array(101...120))
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(analytics.events == [.catalogRefreshed(listContext: .browse, outcome: .success, durationMs: 120)])
    }

    /// AC-C5: pull-to-refresh never blanks the grid, even when it fails.
    @Test func refreshFailureKeepsContent() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(failure: AppError.offline)

        await viewModel.refresh()

        #expect(viewModel.cards.map(\.id) == Array(1...20))
        #expect(viewModel.phase == .content(footer: .idle, refreshError: .offline))
        #expect(analytics.events == [.catalogRefreshed(listContext: .browse, outcome: .failure(.offline), durationMs: 0)])
    }

    @Test func refreshKeepsContentVisibleWhileLoading() async {
        let viewModel = await loadedViewModel()
        let refresh = Task { await viewModel.refresh() }

        await repository.waitForPendingRequests(1)
        #expect(viewModel.cards.count == 20)
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))

        repository.resumeNext(with: .success(page(1...20, total: 194, skip: 0)))
        await refresh.value
    }

    /// D-41: a page that was in flight when the refresh started never lands on the fresh page 1.
    @Test func refreshDropsAnInFlightPageResult() async {
        let viewModel = await loadedViewModel()
        viewModel.itemAppeared(id: 20)
        await repository.waitForPendingRequests(1)
        repository.enqueue(page(1...20, total: 194, skip: 0))

        await viewModel.refresh()
        repository.resumeNext(with: .success(page(21...40, total: 194, skip: 20)))
        await viewModel.pageTask?.value

        #expect(viewModel.cards.map(\.id) == Array(1...20))
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(!analytics.events.contains { $0.name == .catalogPageLoaded })

        repository.enqueue(page(21...40, total: 194, skip: 20))
        viewModel.itemAppeared(id: 20)
        await viewModel.pageTask?.value
        #expect(viewModel.cards.count == 40, "loading more works again after the refresh")
    }

    @Test func loadMoreIsPausedDuringRefresh() async {
        let viewModel = await loadedViewModel()
        let refresh = Task { await viewModel.refresh() }
        await repository.waitForPendingRequests(1)

        viewModel.itemAppeared(id: 20)
        #expect(repository.requests.count == 2, "page 1 and the refresh only")

        repository.resumeNext(with: .success(page(1...20, total: 194, skip: 0)))
        await refresh.value
    }

    /// Review finding 1: the failed-page footer's Retry must not start a page request while a
    /// refresh is in flight.
    @Test func retryPageIsIgnoredDuringRefresh() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(failure: AppError.timeout)
        viewModel.itemAppeared(id: 20)
        await viewModel.pageTask?.value
        let refresh = Task { await viewModel.refresh() }
        await repository.waitForPendingRequests(1)

        repository.enqueue(page(21...40, total: 194, skip: 20))

        viewModel.retryPage()
        viewModel.itemAppeared(id: 20)
        await viewModel.pageTask?.value

        #expect(repository.requests.count == 3, "page 1, the failed page 2 and the refresh only")
        #expect(!analytics.events.contains { $0.name == .retryRequested })

        repository.resumeNext(with: .success(page(1...20, total: 194, skip: 0)))
        await refresh.value
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
    }

    @Test func dismissRefreshErrorClearsBanner() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(failure: AppError.offline)
        await viewModel.refresh()

        viewModel.dismissRefreshError()

        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
    }

    @Test func nextRefreshClearsBanner() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(failure: AppError.offline)
        await viewModel.refresh()

        let refresh = Task { await viewModel.refresh() }
        await repository.waitForPendingRequests(1)
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))

        repository.resumeNext(with: .success(page(1...20, total: 194, skip: 0)))
        await refresh.value
    }

    @Test func cancelledRefreshSendsNothing() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(failure: CancellationError())

        await viewModel.refresh()

        #expect(viewModel.cards.count == 20)
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(analytics.events.isEmpty)
    }

    @Test func refreshToNoProductsShowsEmpty() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(emptyPage(total: 0, skip: 0))

        await viewModel.refresh()

        #expect(viewModel.phase == .empty)
    }

    // MARK: - Teardown

    /// Review finding 4: the view model's own tasks don't keep it alive, and releasing it cancels
    /// them, so no request or event outlives the screen.
    @Test func releasingTheViewModelCancelsAPageLoad() async {
        var viewModel: CatalogViewModel? = await loadedViewModel()
        viewModel?.itemAppeared(id: 20)
        await repository.waitForPendingRequests(1)
        let task = viewModel?.pageTask
        weak var released = viewModel

        viewModel = nil

        #expect(released == nil)
        repository.resumeNext(with: .success(page(21...40, total: 194, skip: 20)))
        await task?.value
        #expect(repository.cancelledRequestCount == 1)
        #expect(analytics.events.map(\.name) == [.catalogPageRequested])
    }

    @Test func releasingTheViewModelCancelsARetry() async {
        repository.enqueue(failure: AppError.offline)
        var viewModel: CatalogViewModel? = makeViewModel()
        await viewModel?.start()
        viewModel?.retry()
        await repository.waitForPendingRequests(1)
        let task = viewModel?.firstPageTask
        weak var released = viewModel

        viewModel = nil

        #expect(released == nil)
        repository.resumeNext(with: .success(page(1...20, total: 194, skip: 0)))
        await task?.value
        #expect(repository.cancelledRequestCount == 1)
        #expect(!analytics.events.contains { $0.name == .catalogLoadCompleted })
    }
}
