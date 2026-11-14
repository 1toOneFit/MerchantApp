import Testing
@testable import MerchantCatalog

/// Server-side sort of the list on screen (ProductSpecification § 4.2, D-45, D-46) and
/// `sort_changed` (Analytics.md § 3 Sorting).
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CatalogViewModelSortTests {
    private let repository = FakeProductRepository()
    private let analytics = SpyAnalytics()
    private let clock = TestClock()

    private func makeViewModel() -> CatalogViewModel {
        CatalogViewModel(repository: repository, analytics: analytics, router: Router(), savedProducts: SavedProductsStore(repository: InMemorySavedRepository(), analytics: SpyAnalytics()), cardExperiment: unobservedCardExperiment(), clock: clock)
    }

    /// A view model browsing products 1...20 of 194, with the analytics so far cleared.
    private func browsingViewModel() async -> CatalogViewModel {
        repository.enqueue(page(1...20, total: 194, skip: 0))
        let viewModel = makeViewModel()
        await viewModel.start()
        analytics.reset()
        return viewModel
    }

    /// Types `text`, lets the debounce pass and waits for the search, answered with `answer`.
    private func search(_ text: String, in viewModel: CatalogViewModel, answer: ProductPage) async {
        repository.enqueue(answer)
        viewModel.searchTextChanged(to: text)
        await clock.waitForSleepers(1)
        clock.advance(by: CatalogViewModel.searchDebounce)
        await viewModel.searchTask?.value
    }

    // MARK: - Browse

    /// D-45: the skeleton shows until page 1 of the new order arrives.
    @Test func sortChangeReloadsFirstPage() async {
        let viewModel = await browsingViewModel()
        repository.onRequest = { [clock] in clock.advance(by: .milliseconds(300)) }
        repository.enqueue(page(101...120, total: 194, skip: 0))

        viewModel.sortSelected(.priceAscending)

        #expect(viewModel.sort == .priceAscending)
        #expect(viewModel.phase == .initialLoading)
        await viewModel.firstPageTask?.value
        #expect(repository.requests.last == .init(sort: .priceAscending, skip: 0, limit: 20))
        #expect(viewModel.cards.map(\.id) == Array(101...120))
        #expect(analytics.events == [
            .sortChanged(from: .defaultOrder, to: .priceAscending, listContext: .browse),
            .catalogLoadCompleted(trigger: .sortChange, sort: .priceAscending, resultCount: 20, totalCount: 194, durationMs: 300),
        ])
    }

    @Test func sameSortDoesNothing() async {
        let viewModel = await browsingViewModel()

        viewModel.sortSelected(.defaultOrder)

        #expect(analytics.events.isEmpty)
        #expect(viewModel.firstPageTask == nil)
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(repository.requests.count == 1)
    }

    /// D-45: `has_visible_content` says products were on screen when the request started; Retry
    /// keeps the new sort.
    @Test func sortChangeFailureReportsVisibleContent() async {
        let viewModel = await browsingViewModel()
        repository.enqueue(failure: AppError.timeout)

        viewModel.sortSelected(.priceAscending)
        await viewModel.firstPageTask?.value

        #expect(viewModel.phase == .failed(.timeout))
        #expect(viewModel.sort == .priceAscending)
        #expect(analytics.events.last == .catalogLoadFailed(trigger: .sortChange, sort: .priceAscending, error: .timeout, hasVisibleContent: true))

        repository.enqueue(page(101...120, total: 194, skip: 0))
        viewModel.retry()
        await viewModel.firstPageTask?.value

        #expect(repository.requests.last == .init(sort: .priceAscending, skip: 0, limit: 20))
        #expect(analytics.events.last == .catalogLoadCompleted(trigger: .retry, sort: .priceAscending, resultCount: 20, totalCount: 194, durationMs: 0))
    }

    @Test func sortChangeDropsAnInFlightPage() async {
        let viewModel = await browsingViewModel()
        viewModel.itemAppeared(id: 20, in: .browse)
        await repository.waitForPendingRequests(1)
        let pageTask = viewModel.pageTask
        repository.enqueue(page(101...120, total: 194, skip: 0))

        viewModel.sortSelected(.priceDescending)
        await viewModel.firstPageTask?.value
        repository.resumeNext(with: .success(page(21...40, total: 194, skip: 20)))
        await pageTask?.value

        #expect(viewModel.cards.map(\.id) == Array(101...120))
        #expect(viewModel.phase == .content(footer: .idle, refreshError: nil))
        #expect(!analytics.events.contains { $0.name == .catalogPageLoaded })
        #expect(repository.cancelledRequestCount == 1)
    }

    @Test func latestSortWins() async {
        let viewModel = await browsingViewModel()
        viewModel.sortSelected(.priceAscending)
        await repository.waitForPendingRequests(1)
        let firstTask = viewModel.firstPageTask

        viewModel.sortSelected(.ratingDescending)
        await repository.waitForPendingRequests(2)
        repository.resumeNewest(with: .success(page(201...220, total: 194, skip: 0)))
        await viewModel.firstPageTask?.value
        repository.resumeNext(with: .success(page(101...120, total: 194, skip: 0)))
        await firstTask?.value

        #expect(viewModel.sort == .ratingDescending)
        #expect(viewModel.cards.map(\.id) == Array(201...220))
        #expect(analytics.events.filter { $0.name == .catalogLoadCompleted } == [
            .catalogLoadCompleted(trigger: .sortChange, sort: .ratingDescending, resultCount: 20, totalCount: 194, durationMs: 0),
        ])
        #expect(repository.cancelledRequestCount == 1, "the second change cancelled the first request")
    }

    /// Review Focus 5: a sort change during a pull-to-refresh wins; load-more works afterwards.
    @Test func sortChangeDuringRefreshWins() async {
        let viewModel = await browsingViewModel()
        let refresh = Task { await viewModel.refresh() }
        await repository.waitForPendingRequests(1)
        repository.enqueue(page(101...120, total: 194, skip: 0))

        viewModel.sortSelected(.priceAscending)
        await viewModel.firstPageTask?.value
        repository.resumeNext(with: .success(page(1...20, total: 194, skip: 0)))
        await refresh.value

        #expect(viewModel.cards.map(\.id) == Array(101...120))
        #expect(!analytics.events.contains { $0.name == .catalogRefreshed })

        repository.enqueue(page(121...140, total: 194, skip: 20))
        viewModel.itemAppeared(id: 120, in: .browse)
        await viewModel.pageTask?.value
        #expect(viewModel.cards.count == 40)
    }

    // MARK: - Search

    /// D-46: a search starts in the sort on screen.
    @Test func searchUsesTheSortOnScreen() async {
        let viewModel = await browsingViewModel()
        repository.enqueue(page(101...120, total: 194, skip: 0))
        viewModel.sortSelected(.ratingDescending)
        await viewModel.firstPageTask?.value

        await search("phone", in: viewModel, answer: page(201...220, total: 23, skip: 0))

        #expect(repository.requests.last == .init(query: "phone", sort: .ratingDescending, skip: 0, limit: 20))
        #expect(viewModel.sort == .ratingDescending)
    }

    @Test func sortChangeWhileSearchingReloadsSearch() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(201...220, total: 23, skip: 0))
        analytics.reset()
        repository.enqueue(page(221...240, total: 23, skip: 0))

        viewModel.sortSelected(.priceAscending)

        #expect(viewModel.listContext == .search)
        #expect(viewModel.phase == .initialLoading)
        await viewModel.searchTask?.value
        #expect(repository.requests.last == .init(query: "phone", sort: .priceAscending, skip: 0, limit: 20))
        #expect(viewModel.cards.map(\.id) == Array(221...240))
        #expect(analytics.events == [
            .sortChanged(from: .defaultOrder, to: .priceAscending, listContext: .search),
            .searchPerformed(trigger: .sortChange, queryLength: 5, wordCount: 1, sort: .priceAscending, resultCount: 20, totalCount: 23, durationMs: 0),
        ])
    }

    /// D-46, AC-S4: a sort picked while searching doesn't change browse; clearing shows browse in
    /// its own sort, without a request.
    @Test func clearingRestoresTheBrowseSort() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(201...220, total: 23, skip: 0))
        repository.enqueue(page(221...240, total: 23, skip: 0))
        viewModel.sortSelected(.priceAscending)
        await viewModel.searchTask?.value
        let requestCount = repository.requests.count

        viewModel.clearSearch()

        #expect(viewModel.sort == .defaultOrder)
        #expect(viewModel.cards.map(\.id) == Array(1...20))
        #expect(repository.requests.count == requestCount)
    }

    // MARK: - Scroll to top

    /// Review finding 2: a sort change gives the browse list a new identity, so the view shows it in
    /// a new grid, from the top.
    @Test func sortChangeStartsANewBrowseList() async {
        let viewModel = await browsingViewModel()
        let listID = viewModel.browseList.listID
        repository.enqueue(page(101...120, total: 194, skip: 0))

        viewModel.sortSelected(.priceAscending)
        await viewModel.firstPageTask?.value

        #expect(viewModel.browseList.listID != listID)
    }

    @Test func sortChangeStartsANewSearchList() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(201...220, total: 23, skip: 0))
        let listID = viewModel.searchList?.listID
        repository.enqueue(page(221...240, total: 23, skip: 0))

        viewModel.sortSelected(.priceAscending)
        await viewModel.searchTask?.value

        #expect(viewModel.searchList?.listID != listID)
    }

    /// Loading more and pull-to-refresh keep the list's identity: the grid and its scroll position
    /// stay.
    @Test func loadMoreAndRefreshKeepTheList() async {
        let viewModel = await browsingViewModel()
        let listID = viewModel.browseList.listID
        repository.enqueue(page(21...40, total: 194, skip: 20))
        viewModel.itemAppeared(id: 20, in: .browse)
        await viewModel.pageTask?.value
        repository.enqueue(page(1...20, total: 194, skip: 0))

        await viewModel.refresh()

        #expect(viewModel.browseList.listID == listID)
    }
}
