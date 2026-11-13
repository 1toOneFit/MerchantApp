import Testing
@testable import MerchantCatalog

/// Pagination and de-duplication rules of the catalog list (ProductSpecification § 4.1,
/// Networking.md A1–A2).
struct CatalogListStateTests {
    @Test func startsWithNothingToLoad() {
        let state = CatalogListState()

        #expect(state.isEmpty)
        #expect(!state.canLoadMore)
        #expect(state.pagesLoaded == 0)
    }

    @Test func replaceStartsOver() {
        var state = CatalogListState()
        state.replace(with: page(1...20, total: 194, skip: 0))
        state.append(page(21...40, total: 194, skip: 20))

        state.replace(with: page(101...120, total: 150, skip: 0))

        #expect(state.items.map(\.id) == Array(101...120))
        #expect(state.total == 150)
        #expect(state.nextSkip == 20)
        #expect(state.pagesLoaded == 1)
        #expect(state.canLoadMore)
    }

    /// The server's order is global, but a tie at a page boundary could repeat a product (A2).
    @Test func appendAddsOnlyNewIDs() {
        var state = CatalogListState()
        state.replace(with: page(1...20, total: 194, skip: 0))

        let added = state.append(page(19...38, total: 194, skip: 20))

        #expect(added == 18)
        #expect(state.items.map(\.id) == Array(1...38))
        #expect(state.nextSkip == 40)
        #expect(state.pagesLoaded == 2)
    }

    @Test func canLoadMoreUntilTotal() {
        var state = CatalogListState()

        state.replace(with: page(1...20, total: 45, skip: 0))
        #expect(state.canLoadMore)

        state.append(page(21...40, total: 45, skip: 20))
        #expect(state.canLoadMore)

        state.append(page(41...45, total: 45, skip: 40))
        #expect(!state.canLoadMore)
        #expect(state.items.count == 45)
    }

    @Test func emptyFirstPageIsEmpty() {
        var state = CatalogListState()

        state.replace(with: emptyPage(total: 0, skip: 0))

        #expect(state.isEmpty)
        #expect(state.pagesLoaded == 1)
        #expect(!state.canLoadMore)
    }

    /// An empty page before `total` would otherwise request the same `skip` forever.
    @Test func emptyPageStopsPagination() {
        var state = CatalogListState()
        state.replace(with: page(1...20, total: 194, skip: 0))

        let added = state.append(emptyPage(total: 194, skip: 20))

        #expect(added == 0)
        #expect(!state.canLoadMore)
        #expect(state.items.count == 20)
    }
}
