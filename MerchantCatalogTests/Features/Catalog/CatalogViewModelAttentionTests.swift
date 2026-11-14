import Testing
@testable import MerchantCatalog

/// Needs attention (D-85): a scope of the list on screen that shows only its loaded products that
/// are low or out of stock, in server order, with how many there are and what that is based on. No
/// extra request; in the scope, cards don't page automatically and "Check 20 more products" does.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CatalogViewModelAttentionTests {
    private let repository = FakeProductRepository()
    private let analytics = SpyAnalytics()
    private let clock = TestClock()
    private let now = TestNow()

    private func makeViewModel(store: SavedProductsStore? = nil) -> CatalogViewModel {
        CatalogViewModel(repository: repository, analytics: analytics, router: Router(), savedProducts: store ?? SavedProductsStore(repository: InMemorySavedRepository(), analytics: SpyAnalytics()), cardExperiment: unobservedCardExperiment(), clock: clock)
    }

    /// Products `ids` with stock from `stock(id)`, as the server would report them at `skip`.
    private static func stockPage(_ ids: ClosedRange<Int>, total: Int, skip: Int, stock: (Int) -> Int?) -> ProductPage {
        ProductPage(products: ids.map { makeSummary(id: $0, stock: stock($0)) }, total: total, skip: skip, limit: ids.count)
    }

    /// Page 1: 3 out of stock, 5 low (1...10), 12 in stock (> 10).
    private static func firstPage(total: Int = 194) -> ProductPage {
        stockPage(1...20, total: total, skip: 0) { id in
            switch id {
            case 3, 9, 17: 0
            case 2, 5, 11, 14, 20: id % 10 + 1
            default: 50
            }
        }
    }

    private static let firstPageAttentionIDs = [2, 3, 5, 9, 11, 14, 17, 20]

    private func loadedViewModel(total: Int = 194, store: SavedProductsStore? = nil) async -> CatalogViewModel {
        repository.enqueue(Self.firstPage(total: total))
        let viewModel = makeViewModel(store: store)
        await viewModel.start()
        analytics.reset()
        return viewModel
    }

    @Test func attentionCountCountsLowAndOutOfStock() async {
        let viewModel = makeViewModel()
        #expect(viewModel.attentionCount == nil, "no count before the list has content")
        repository.enqueue(Self.firstPage())

        await viewModel.start()

        #expect(viewModel.attentionCount == 8)
    }

    /// Review Focus 3: unknown stock never needs attention.
    @Test func unknownStockIsNotCounted() async {
        repository.enqueue(Self.stockPage(1...4, total: 4, skip: 0) { $0 == 1 ? nil : 50 })
        let viewModel = makeViewModel()

        await viewModel.start()

        #expect(viewModel.attentionCount == 0)
    }

    @Test func startsInAllProducts() async {
        let viewModel = await loadedViewModel()

        #expect(viewModel.scope == .all)
        #expect(viewModel.browseList.cards.map(\.id) == Array(1...20))
    }

    @Test func needsAttentionShowsOnlyAttentionCardsInServerOrder() async {
        let viewModel = await loadedViewModel()

        viewModel.scopeSelected(.needsAttention)

        #expect(viewModel.scope == .needsAttention)
        #expect(viewModel.cards.map(\.id) == Self.firstPageAttentionIDs)
        #expect(viewModel.browseList.cards.map(\.id) == Self.firstPageAttentionIDs)
        #expect(viewModel.browseList.scope == .needsAttention)
        #expect(repository.requests.count == 1, "no extra request")
    }

    @Test func backToAllProductsShowsEveryCard() async {
        let viewModel = await loadedViewModel()
        viewModel.scopeSelected(.needsAttention)

        viewModel.scopeSelected(.all)

        #expect(viewModel.cards.map(\.id) == Array(1...20))
    }

    @Test func countUpdatesWhenAPageLoads() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(Self.stockPage(21...40, total: 194, skip: 20) { $0 == 40 ? 2 : 50 })

        viewModel.itemAppeared(id: 20, in: .browse)
        await viewModel.pageTask?.value

        #expect(viewModel.attentionCount == 9)
        viewModel.scopeSelected(.needsAttention)
        #expect(viewModel.cards.map(\.id) == Self.firstPageAttentionIDs + [40])
    }

    /// Review Focus 1: the filtered list's last card isn't the loaded list's end.
    @Test func attentionScopeDoesNotPageOnAppear() async {
        let viewModel = await loadedViewModel()
        viewModel.scopeSelected(.needsAttention)

        viewModel.itemAppeared(id: 20, in: .browse)

        #expect(viewModel.pageTask == nil)
        #expect(repository.requests.count == 1)
    }

    @Test func loadMoreTappedRequestsTheNextPage() async {
        let viewModel = await loadedViewModel()
        viewModel.scopeSelected(.needsAttention)
        repository.enqueue(Self.stockPage(21...40, total: 194, skip: 20) { $0 == 21 ? 0 : 50 })

        viewModel.loadMoreTapped()
        viewModel.loadMoreTapped()
        await viewModel.pageTask?.value

        #expect(Array(repository.requests.dropFirst()) == [.init(sort: .defaultOrder, skip: 20, limit: 20)], "one request")
        #expect(viewModel.cards.map(\.id) == Self.firstPageAttentionIDs + [21])
        #expect(analytics.events.first == .catalogPageRequested(listContext: .browse, pageIndex: 2, sort: .defaultOrder, isRetry: false))
    }

    @Test func loadMoreTappedPastTheEndDoesNothing() async {
        let viewModel = await loadedViewModel(total: 20)
        viewModel.scopeSelected(.needsAttention)

        viewModel.loadMoreTapped()

        #expect(viewModel.pageTask == nil)
        #expect(repository.requests.count == 1)
    }

    @Test func coverageReportsLoadedOfTotal() async {
        let viewModel = await loadedViewModel()
        viewModel.scopeSelected(.needsAttention)

        #expect(viewModel.browseList.coverage == AttentionCoverage(loaded: 20, total: 194, remaining: 174, isComplete: false))
    }

    /// Review finding 1: an empty page stops paging (an inconsistent server response, D-85), but the
    /// products after it were never loaded, so the count is not "all" of them.
    @Test func coverageIsNotCompleteAfterAnEmptyPageBeforeTheEnd() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(emptyPage(total: 194, skip: 20))

        viewModel.itemAppeared(id: 20, in: .browse)
        await viewModel.pageTask?.value

        #expect(viewModel.phase == .content(footer: .end, refreshError: nil), "paging stops as before")
        #expect(viewModel.browseList.coverage == AttentionCoverage(loaded: 20, total: 194, remaining: 174, isComplete: false))
    }

    @Test func coverageIsCompleteWhenEverythingIsLoaded() async {
        let viewModel = await loadedViewModel(total: 20)

        #expect(viewModel.browseList.coverage == AttentionCoverage(loaded: 20, total: 20, remaining: 0, isComplete: true))
    }

    /// Review Focus 2: while searching, the scope filters the search results.
    @Test func attentionScopeFiltersSearchResults() async {
        let viewModel = await loadedViewModel()
        viewModel.scopeSelected(.needsAttention)
        repository.enqueue(Self.stockPage(101...104, total: 4, skip: 0) { $0 == 102 ? 3 : 50 })

        viewModel.searchTextChanged(to: "lamp")
        await clock.waitForSleepers(1)
        clock.advance(by: CatalogViewModel.searchDebounce)
        await viewModel.searchTask?.value

        #expect(viewModel.listContext == .search)
        #expect(viewModel.cards.map(\.id) == [102])
        #expect(viewModel.attentionCount == 1)
        #expect(viewModel.searchList?.cards.map(\.id) == [102])
    }

    // MARK: - Analytics positions (review finding 2)

    /// `position` is the index in the list on screen: in Needs attention, the filtered list.
    @Test func selectingInNeedsAttentionReportsTheVisiblePosition() async {
        let viewModel = await loadedViewModel()
        viewModel.scopeSelected(.needsAttention)

        viewModel.cardSelected(id: 9, in: .browse)

        #expect(analytics.events == [.productSelected(productID: 9, source: .catalog, position: 3, sort: .defaultOrder)])
    }

    /// The position is the filtered list's; the saved snapshot is still the loaded product.
    @Test func savingInNeedsAttentionReportsTheVisiblePosition() async {
        let store = await loadedSavedStore(now: now.now)
        let viewModel = await loadedViewModel(store: store)
        viewModel.scopeSelected(.needsAttention)

        viewModel.saveToggled(id: 9, in: .browse)

        #expect(analytics.events == [
            .productSaved(productID: 9, surface: .catalogCard, category: nil, price: product(9).price, position: 3, savedCountAfter: 1),
        ])
        #expect(store.item(id: 9) == SavedProduct(summary: makeSummary(id: 9), savedAt: now.date))
    }

    @Test func positionsAfterPaginationCountTheListOnScreen() async {
        let viewModel = await loadedViewModel()
        repository.enqueue(Self.stockPage(21...40, total: 194, skip: 20) { $0 == 40 ? 2 : 50 })
        viewModel.itemAppeared(id: 20, in: .browse)
        await viewModel.pageTask?.value
        analytics.reset()

        viewModel.cardSelected(id: 40, in: .browse)
        viewModel.scopeSelected(.needsAttention)
        viewModel.cardSelected(id: 40, in: .browse)

        #expect(analytics.events == [
            .productSelected(productID: 40, source: .catalog, position: 39, sort: .defaultOrder),
            .productSelected(productID: 40, source: .catalog, position: 8, sort: .defaultOrder),
        ])
    }

    @Test func searchResultsInNeedsAttentionReportTheVisiblePosition() async {
        let viewModel = await loadedViewModel()
        viewModel.scopeSelected(.needsAttention)
        repository.enqueue(Self.stockPage(101...104, total: 4, skip: 0) { $0 == 102 || $0 == 104 ? 3 : 50 })
        viewModel.searchTextChanged(to: "lamp")
        await clock.waitForSleepers(1)
        clock.advance(by: CatalogViewModel.searchDebounce)
        await viewModel.searchTask?.value
        analytics.reset()

        viewModel.cardSelected(id: 9, in: .browse)
        viewModel.cardSelected(id: 104, in: .search)

        #expect(analytics.events == [.productSelected(productID: 104, source: .search, position: 1, sort: .defaultOrder)], "the hidden browse card is ignored")
    }

    /// A card that the scope doesn't show can't be on screen; a stray callback changes nothing.
    @Test func cardOutsideTheScopeIsIgnored() async {
        let viewModel = await loadedViewModel()
        viewModel.scopeSelected(.needsAttention)

        viewModel.cardSelected(id: 1, in: .browse)
        viewModel.saveToggled(id: 1, in: .browse)

        #expect(analytics.events.isEmpty)
        #expect(!viewModel.isSaved(1))
    }

    @Test func selectingTheSameScopeIsANoOp() async {
        let viewModel = await loadedViewModel()

        viewModel.scopeSelected(.all)

        #expect(viewModel.scope == .all)
        #expect(analytics.events.isEmpty)
    }
}
