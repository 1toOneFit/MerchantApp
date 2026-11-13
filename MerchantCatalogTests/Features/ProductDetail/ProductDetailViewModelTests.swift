import Foundation
import Testing
@testable import MerchantCatalog

/// The details screen's state and events (ProductSpecification § 4.3; Analytics.md § 3 Details):
/// content comes from the list's product without a request (AC-D1); `product_details_viewed` once
/// per push and `product_gallery_interacted` once per visit (D-59).
@MainActor
struct ProductDetailViewModelTests {
    private let analytics = SpyAnalytics()
    private let repository = FakeProductRepository()
    private let now = TestNow()

    private static let images = (1...3).compactMap { URL(string: "https://cdn.dummyjson.com/products/1/\($0).webp") }
    private static let mascara = makeProduct(
        id: 1,
        title: "Volume Mascara",
        brand: "Acme",
        availability: .lowStock,
        imageURLs: images,
        category: "beauty",
        rating: 4.94,
        discountPercentage: 7.17,
        stock: 5
    )

    private func makeViewModel(
        product: Product = mascara,
        source: ProductSource = .search,
        store: SavedProductsStore? = nil
    ) -> ProductDetailViewModel {
        ProductDetailViewModel(
            route: .list(product, source: source),
            repository: repository,
            savedProducts: store ?? SavedProductsStore(repository: InMemorySavedRepository(), analytics: SpyAnalytics()),
            analytics: analytics
        )
    }

    /// AC-D1: everything is there at once; nothing is tracked before the screen appears.
    @Test func exposesHeaderInsightsAndGallery() {
        let viewModel = makeViewModel()

        #expect(viewModel.header == ProductDetailHeader(Self.mascara))
        #expect(viewModel.insights == ProductInsights(Self.mascara))
        #expect(viewModel.gallery == ProductGalleryModel(Self.mascara))
        #expect(viewModel.galleryIndex == 0)
        #expect(analytics.events.isEmpty)
    }

    @Test func detailsViewedOncePerScreen() {
        let viewModel = makeViewModel()

        viewModel.contentAppeared()
        viewModel.contentAppeared()

        #expect(analytics.events == [
            .productDetailsViewed(productID: 1, source: .search, category: "beauty", availability: .lowStock, hasDiscount: true, imageCount: 3, savedAt: nil, contentOrigin: .list),
        ])
    }

    @Test func detailsViewedReportsMissingData() {
        let viewModel = makeViewModel(product: makeProduct(id: 2, discountPercentage: 0), source: .catalog)

        viewModel.contentAppeared()

        #expect(analytics.events == [
            .productDetailsViewed(productID: 2, source: .catalog, category: nil, availability: nil, hasDiscount: false, imageCount: 0, savedAt: nil, contentOrigin: .list),
        ])
    }

    /// A new push builds a new view model, so it reports its own view.
    @Test func eachPushTracksItsOwnView() {
        makeViewModel().contentAppeared()
        makeViewModel().contentAppeared()

        #expect(analytics.events.count == 2)
    }

    @Test func galleryEventFiresOnceOnTheFirstSwipe() {
        let viewModel = makeViewModel()

        viewModel.galleryPageChanged(to: 0)
        #expect(analytics.events.isEmpty, "the image already shown is not a swipe")

        viewModel.galleryPageChanged(to: 1)
        viewModel.galleryPageChanged(to: 2)
        viewModel.galleryPageChanged(to: 0)

        #expect(analytics.events == [.productGalleryInteracted(productID: 1, imageCount: 3)])
        #expect(viewModel.galleryIndex == 0)
    }

    // MARK: - Saving (S5)

    /// `is_saved` comes from the store when details appear; the save date travels with the event
    /// for `saved_product_revisited` (D-64).
    @Test func detailsViewedReportsTheSavedDate() async {
        let savedAt = date("2026-11-10T10:00:00Z")
        let store = await loadedSavedStore([SavedProduct(Self.mascara, savedAt: savedAt)])
        let viewModel = makeViewModel(store: store)

        viewModel.contentAppeared()

        #expect(analytics.events == [
            .productDetailsViewed(productID: 1, source: .search, category: "beauty", availability: .lowStock, hasDiscount: true, imageCount: 3, savedAt: savedAt, contentOrigin: .list),
        ])
    }

    @Test func toolbarSaveAndUnsaveTrackDetailsSurface() async {
        let store = await loadedSavedStore(now: now.now)
        let viewModel = makeViewModel(store: store)

        viewModel.saveToggled()
        #expect(viewModel.isSaved)
        now.advance(by: 30)
        viewModel.saveToggled()

        #expect(!viewModel.isSaved)
        #expect(analytics.events == [
            .productSaved(productID: 1, surface: .details, category: "beauty", price: Self.mascara.price, position: nil, savedCountAfter: 1),
            .productUnsaved(productID: 1, surface: .details, savedDurationS: 30, savedCountAfter: 0),
        ])
    }

    /// Details from a list need no request (A7).
    @Test func listRouteNeverFetches() async {
        let viewModel = makeViewModel()

        await viewModel.start()

        #expect(repository.productRequests.isEmpty)
        #expect(viewModel.refresh == .idle)
        #expect(!viewModel.isShowingSnapshot)
    }

    /// AC-D3: saving on details shows on the catalog card at once; both read one store.
    @Test func saveOnDetailsUpdatesTheCatalogCard() async {
        let store = await loadedSavedStore()
        let catalog = CatalogViewModel(repository: FakeProductRepository(), analytics: SpyAnalytics(), router: Router(), savedProducts: store, clock: TestClock())
        let viewModel = makeViewModel(store: store)

        viewModel.saveToggled()

        #expect(catalog.isSaved(1))
    }
}
