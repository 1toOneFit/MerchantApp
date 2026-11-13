import Foundation
import Testing
@testable import MerchantCatalog

/// The Saved tab (ProductSpecification § 4.4, AC-V1, AC-V3, AC-V4): rows from the shared store,
/// newest first and without the network; a row opens details from the snapshot; swipe removes; the
/// empty state's Browse catalog switches tabs (D-61).
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SavedViewModelTests {
    private let analytics = SpyAnalytics()
    private let router = Router()
    private let tabs = TabSelection(selected: .saved)
    private let now = TestNow()

    private func saved(_ id: Int, at iso: String) -> SavedProduct {
        SavedProduct(product(id), savedAt: date(iso))
    }

    private var items: [SavedProduct] {
        [saved(5, at: "2026-11-12T10:00:00Z"), saved(2, at: "2026-11-10T10:00:00Z")]
    }

    private func makeViewModel(store: SavedProductsStore) -> SavedViewModel {
        SavedViewModel(savedProducts: store, analytics: analytics, router: router, tabs: tabs)
    }

    @Test func rowsFollowTheStoreNewestFirst() async {
        let store = await loadedSavedStore(items, now: now.now)
        let viewModel = makeViewModel(store: store)

        #expect(viewModel.rows == items.map { SavedRowModel($0) })

        store.save(product(9))
        #expect(viewModel.rows.map(\.id) == [9, 5, 2])
    }

    @Test func phaseFollowsTheStore() async {
        let store = SavedProductsStore(repository: InMemorySavedRepository(stored: items), analytics: SpyAnalytics(), now: now.now)
        let viewModel = makeViewModel(store: store)
        #expect(viewModel.phase == .loading)

        await store.load()
        #expect(viewModel.phase == .content)

        store.remove(id: 5)
        store.remove(id: 2)
        #expect(viewModel.phase == .empty)
    }

    @Test func viewedEventCountsSavedProducts() async {
        let viewModel = makeViewModel(store: await loadedSavedStore(items))

        viewModel.savedBecameVisible()

        #expect(analytics.events == [.savedProductsViewed(savedCount: 2)])
    }

    @Test func rowTapTracksAndPushesTheSavedRoute() async {
        let viewModel = makeViewModel(store: await loadedSavedStore(items))

        viewModel.rowSelected(id: 2)

        #expect(analytics.events == [.productSelected(productID: 2, source: .saved, position: 1, sort: nil)])
        #expect(router.path == [.productDetail(.saved(items[1]))])
    }

    @Test func unknownRowIsIgnored() async {
        let viewModel = makeViewModel(store: await loadedSavedStore(items))

        viewModel.rowSelected(id: 99)
        viewModel.removeSwiped(id: 99)

        #expect(analytics.events.isEmpty)
        #expect(router.path.isEmpty)
    }

    @Test func swipeRemovesAndTracks() async {
        now.date = date("2026-11-13T10:00:00Z")
        let store = await loadedSavedStore(items, now: now.now)
        let viewModel = makeViewModel(store: store)

        viewModel.removeSwiped(id: 5)

        #expect(analytics.events == [.productUnsaved(productID: 5, surface: .savedList, savedDurationS: 86_400, savedCountAfter: 1)])
        #expect(viewModel.rows.map(\.id) == [2])
    }

    /// AC-V4: the catalog card follows a swipe in Saved.
    @Test func swipeUpdatesTheCatalogCard() async {
        let store = await loadedSavedStore(items)
        let catalog = CatalogViewModel(repository: FakeProductRepository(), analytics: SpyAnalytics(), router: Router(), savedProducts: store, cardExperiment: unobservedCardExperiment(), clock: TestClock())
        let viewModel = makeViewModel(store: store)

        viewModel.removeSwiped(id: 5)

        #expect(!catalog.isSaved(5))
    }

    @Test func browseCatalogSwitchesToTheCatalogTab() async {
        let viewModel = makeViewModel(store: await loadedSavedStore())

        viewModel.browseCatalogTapped()

        #expect(tabs.selected == .catalog)
        #expect(analytics.events.isEmpty)
    }
}
