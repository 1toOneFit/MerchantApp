import Testing
@testable import MerchantCatalog

/// Opening product details from the catalog (ProductSpecification § 4.3, AC-C6) and
/// `product_selected` (Analytics.md § 3): the tap is reported from the list on screen and pushed
/// onto the Catalog tab's router (D-53); the catalog's state is kept while details are open and
/// after going back, the search included (D-54).
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CatalogViewModelSelectionTests {
    private let repository = FakeProductRepository()
    private let analytics = SpyAnalytics()
    private let clock = TestClock()
    private let router = Router()

    /// A view model browsing products 1...20 of 194, with the analytics so far cleared.
    private func browsingViewModel() async -> CatalogViewModel {
        repository.enqueue(page(1...20, total: 194, skip: 0))
        let viewModel = CatalogViewModel(repository: repository, analytics: analytics, router: router, savedProducts: SavedProductsStore(repository: InMemorySavedRepository(), analytics: SpyAnalytics()), cardExperiment: unobservedCardExperiment(), clock: clock)
        await viewModel.start()
        analytics.reset()
        return viewModel
    }

    /// Searches `text`, answered with `answer`, and clears the analytics.
    private func search(_ text: String, in viewModel: CatalogViewModel, answer: ProductPage) async {
        repository.enqueue(answer)
        viewModel.searchTextChanged(to: text)
        await clock.waitForSleepers(1)
        clock.advance(by: CatalogViewModel.searchDebounce)
        await viewModel.searchTask?.value
        analytics.reset()
    }

    private func detail(_ id: Int, _ source: ProductSource) -> Route {
        .productDetail(.list(summary(id), source: source))
    }

    @Test func selectingABrowseCardTracksAndPushes() async {
        let viewModel = await browsingViewModel()

        viewModel.cardSelected(id: 4, in: .browse)

        #expect(analytics.events == [.productSelected(productID: 4, source: .catalog, position: 3, sort: .defaultOrder)])
        #expect(router.path == [detail(4, .catalog)])
    }

    /// Source, position and sort come from the search list while results are shown (D-46).
    @Test func selectingASearchResultUsesTheSearchList() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(101...103, total: 3, skip: 0))
        repository.enqueue(page(101...103, total: 3, skip: 0))
        viewModel.sortSelected(.priceAscending)
        await viewModel.searchTask?.value
        analytics.reset()

        viewModel.cardSelected(id: 102, in: .search)

        #expect(analytics.events == [.productSelected(productID: 102, source: .search, position: 1, sort: .priceAscending)])
        #expect(router.path == [detail(102, .search)])
    }

    /// Review Focus 5: the position counts every loaded page of the list.
    @Test func positionCountsLoadedPages() async {
        let viewModel = await browsingViewModel()
        repository.enqueue(page(21...40, total: 194, skip: 20))
        viewModel.itemAppeared(id: 20, in: .browse)
        await viewModel.pageTask?.value
        analytics.reset()

        viewModel.cardSelected(id: 25, in: .browse)

        #expect(analytics.events == [.productSelected(productID: 25, source: .catalog, position: 24, sort: .defaultOrder)])
    }

    /// Review Focus 2: the browse layer under search results can't open details (D-47).
    @Test func hiddenListCardIsIgnored() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(101...103, total: 3, skip: 0))

        viewModel.cardSelected(id: 4, in: .browse)

        #expect(analytics.events.isEmpty)
        #expect(router.path.isEmpty)
    }

    @Test func unknownCardIsIgnored() async {
        let viewModel = await browsingViewModel()

        viewModel.cardSelected(id: 999, in: .browse)

        #expect(analytics.events.isEmpty)
        #expect(router.path.isEmpty)
    }

    /// Review Focus 3, AC-C6 (D-54): a dismissal reported while details are open keeps the search;
    /// back on the catalog, Cancel ends it as before.
    @Test func searchSurvivesDismissalWhileDetailsArePushed() async {
        let viewModel = await browsingViewModel()
        await search("phone", in: viewModel, answer: page(101...103, total: 3, skip: 0))
        let requestCount = repository.requests.count
        viewModel.cardSelected(id: 101, in: .search)
        analytics.reset()

        viewModel.searchDismissed()

        #expect(viewModel.listContext == .search)
        #expect(viewModel.searchText == "phone")
        #expect(viewModel.cards.map(\.id) == [101, 102, 103])
        #expect(analytics.events.isEmpty)
        #expect(repository.requests.count == requestCount)

        router.pop()
        viewModel.searchDismissed()

        #expect(viewModel.listContext == .browse)
        #expect(analytics.events == [.searchCleared(queryLength: 5, hadResults: true)])
    }

    /// AC-C6: going back shows the catalog as it was, without a request.
    @Test func returningFromDetailsKeepsBrowseState() async {
        let viewModel = await browsingViewModel()
        repository.enqueue(page(1...20, total: 194, skip: 0))
        viewModel.sortSelected(.ratingDescending)
        await viewModel.firstPageTask?.value
        repository.enqueue(page(21...40, total: 194, skip: 20))
        viewModel.itemAppeared(id: 20, in: .browse)
        await viewModel.pageTask?.value
        let requestCount = repository.requests.count

        viewModel.cardSelected(id: 30, in: .browse)
        router.pop()
        // The view's `.task` runs again on return. A reload would get this page instead of hanging.
        repository.enqueue(page(1...20, total: 194, skip: 0))
        await viewModel.start()

        #expect(viewModel.cards.map(\.id) == Array(1...40))
        #expect(viewModel.sort == .ratingDescending)
        #expect(viewModel.listContext == .browse)
        #expect(repository.requests.count == requestCount)
    }
}
