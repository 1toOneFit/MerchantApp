import Foundation
import Testing
@testable import MerchantCatalog

/// Saving from catalog cards (ProductSpecification § 4.4, AC-V1): the card's save button toggles
/// the shared store and reports `product_saved` / `product_unsaved` from the list on screen.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CatalogViewModelSaveTests {
    private let repository = FakeProductRepository()
    private let analytics = SpyAnalytics()
    private let clock = TestClock()
    private let now = TestNow()

    /// A view model browsing products 1...20 of 194 over `store`, with the analytics so far cleared.
    private func browsingViewModel(store: SavedProductsStore) async -> CatalogViewModel {
        repository.enqueue(page(1...20, total: 194, skip: 0))
        let viewModel = CatalogViewModel(repository: repository, analytics: analytics, router: Router(), savedProducts: store, clock: clock)
        await viewModel.start()
        analytics.reset()
        return viewModel
    }

    private func makeStore(_ items: [SavedProduct] = []) async -> SavedProductsStore {
        await loadedSavedStore(items, now: now.now)
    }

    @Test func savingABrowseCardTracksAndUpdatesTheStore() async {
        let store = await makeStore()
        let viewModel = await browsingViewModel(store: store)

        viewModel.saveToggled(id: 4, in: .browse)

        #expect(analytics.events == [
            .productSaved(productID: 4, surface: .catalogCard, category: nil, price: product(4).price, position: 3, savedCountAfter: 1),
        ])
        #expect(viewModel.isSaved(4))
        #expect(store.item(id: 4) == SavedProduct(product(4), savedAt: now.date))
    }

    @Test func unsavingACardTracksTheDuration() async {
        let store = await makeStore([SavedProduct(product(4), savedAt: now.date - 120)])
        let viewModel = await browsingViewModel(store: store)

        viewModel.saveToggled(id: 4, in: .browse)

        #expect(analytics.events == [.productUnsaved(productID: 4, surface: .catalogCard, savedDurationS: 120, savedCountAfter: 0)])
        #expect(!viewModel.isSaved(4))
    }

    @Test func searchCardUsesTheSearchSurfaceAndPosition() async {
        let viewModel = await browsingViewModel(store: await makeStore())
        repository.enqueue(page(101...103, total: 3, skip: 0))
        viewModel.searchTextChanged(to: "phone")
        await clock.waitForSleepers(1)
        clock.advance(by: CatalogViewModel.searchDebounce)
        await viewModel.searchTask?.value
        analytics.reset()

        viewModel.saveToggled(id: 103, in: .search)

        #expect(analytics.events == [
            .productSaved(productID: 103, surface: .searchCard, category: nil, price: product(103).price, position: 2, savedCountAfter: 1),
        ])
    }

    /// The hidden browse layer's buttons can't act (D-47).
    @Test func hiddenListSaveIsIgnored() async {
        let store = await makeStore()
        let viewModel = await browsingViewModel(store: store)
        repository.enqueue(page(101...103, total: 3, skip: 0))
        viewModel.searchTextChanged(to: "phone")
        await clock.waitForSleepers(1)
        clock.advance(by: CatalogViewModel.searchDebounce)
        await viewModel.searchTask?.value
        analytics.reset()

        viewModel.saveToggled(id: 4, in: .browse)

        #expect(analytics.events.isEmpty)
        #expect(store.count == 0)
    }

    @Test func unknownCardSaveIsIgnored() async {
        let store = await makeStore()
        let viewModel = await browsingViewModel(store: store)

        viewModel.saveToggled(id: 999, in: .browse)

        #expect(analytics.events.isEmpty)
        #expect(store.count == 0)
    }

    /// AC-V1: a save anywhere else (details, Saved) shows on the card at once.
    @Test func isSavedFollowsChangesFromElsewhere() async {
        let store = await makeStore()
        let viewModel = await browsingViewModel(store: store)

        store.save(product(2))
        #expect(viewModel.isSaved(2))

        store.remove(id: 2)
        #expect(!viewModel.isSaved(2))
    }
}
