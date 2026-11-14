import Foundation
import Testing
@testable import MerchantCatalog

/// Details opened from the catalog or search (ProductSpecification § 4.3, D-81): the list item's
/// summary shows at once, `/products/{id}` loads the full product. `product_details_viewed` is sent
/// once the full product arrives (once per push); a failure keeps the header with a banner and Retry;
/// `product_gallery_interacted` once per visit (D-59).
@MainActor
@Suite(.timeLimit(.minutes(1)))
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
    private static let viewedMascara = AnalyticsEvent.productDetailsViewed(
        productID: 1, source: .search, category: "beauty", availability: .lowStock, hasDiscount: true, imageCount: 3, savedAt: nil, contentOrigin: .network
    )

    private func makeViewModel(
        summary: ProductSummary = mascara.summary,
        source: ProductSource = .search,
        store: SavedProductsStore? = nil
    ) -> ProductDetailViewModel {
        ProductDetailViewModel(
            route: .list(summary, source: source),
            repository: repository,
            savedProducts: store ?? SavedProductsStore(repository: InMemorySavedRepository(), analytics: SpyAnalytics()),
            analytics: analytics
        )
    }

    /// A view model whose first load returned `product`, analytics cleared.
    private func loadedViewModel(_ product: Product = mascara, source: ProductSource = .search, store: SavedProductsStore? = nil) async -> ProductDetailViewModel {
        let viewModel = makeViewModel(summary: product.summary, source: source, store: store)
        repository.enqueueProduct(.success(product))
        await viewModel.start()
        return viewModel
    }

    // MARK: - Loading

    /// The header shows at once from the list item; the rest waits for the request. Nothing is
    /// requested or tracked before the screen starts.
    @Test func showsTheSummaryFirst() {
        let viewModel = makeViewModel()

        #expect(viewModel.product == Self.mascara.summary.displayProduct)
        #expect(viewModel.header == ProductDetailHeader(title: "Volume Mascara", brand: nil, category: "Beauty"))
        #expect(viewModel.gallery.imageURLs.isEmpty)
        #expect(viewModel.showsGallerySkeleton)
        #expect(viewModel.refresh == .idle)
        #expect(!viewModel.isShowingSnapshot)
        #expect(repository.productRequests.isEmpty)
        #expect(analytics.events.isEmpty)
    }

    @Test func startLoadsTheFullProduct() async {
        let viewModel = makeViewModel()
        repository.enqueueProduct(.success(Self.mascara))

        await viewModel.start()

        #expect(repository.productRequests == [1])
        #expect(viewModel.refresh == .refreshed)
        #expect(viewModel.product == Self.mascara)
        #expect(viewModel.header == ProductDetailHeader(Self.mascara))
        #expect(viewModel.insights == ProductInsights(Self.mascara))
        #expect(viewModel.gallery == ProductGalleryModel(Self.mascara))
    }

    /// While the request runs, a skeleton stands where the gallery will be, instead of a text line;
    /// the images replace it when the product arrives.
    @Test func showsTheGallerySkeletonWhileLoading() async {
        let viewModel = makeViewModel()
        let task = Task { await viewModel.start() }

        await repository.waitForPendingProductRequests(1)
        #expect(viewModel.refresh == .loading)
        #expect(viewModel.showsGallerySkeleton)
        #expect(viewModel.statusMessage == nil)

        repository.resumeNextProduct(with: .success(Self.mascara))
        await task.value
        #expect(viewModel.refresh == .refreshed)
        #expect(!viewModel.showsGallerySkeleton)
        #expect(viewModel.gallery.imageURLs == Self.images)
    }

    /// Leaving the screen cancels the request; a response that wins the race is dropped and the next
    /// appearance loads again.
    @Test func cancellationAppliesNothing() async {
        let viewModel = makeViewModel()
        let task = Task { await viewModel.start() }

        await repository.waitForPendingProductRequests(1)
        task.cancel()
        repository.resumeNextProduct(with: .success(Self.mascara))
        await task.value

        #expect(viewModel.refresh == .idle)
        #expect(viewModel.product == Self.mascara.summary.displayProduct)
        #expect(analytics.events.isEmpty)
    }

    @Test func loadsOncePerScreen() async {
        let viewModel = await loadedViewModel()

        await viewModel.start()

        #expect(repository.productRequests == [1])
    }

    // MARK: - Failure

    @Test func failureKeepsTheHeaderWithRetry() async {
        let viewModel = makeViewModel()
        repository.enqueueProduct(.failure(AppError.offline))

        await viewModel.start()

        #expect(viewModel.refresh == .failed(.offline))
        #expect(viewModel.product == Self.mascara.summary.displayProduct)
        #expect(!viewModel.showsGallerySkeleton)
        #expect(viewModel.statusMessage == "Couldn't load details")
        #expect(analytics.events == [
            .productDetailsLoadFailed(productID: 1, source: .search, error: .offline, showingSnapshot: false),
        ])
    }

    @Test func notFoundMeansNoLongerAvailable() async {
        let viewModel = makeViewModel(source: .catalog)
        repository.enqueueProduct(.failure(AppError.notFound))

        await viewModel.start()

        #expect(viewModel.refresh == .unavailable)
        #expect(!viewModel.showsGallerySkeleton)
        #expect(analytics.events == [
            .productDetailsLoadFailed(productID: 1, source: .catalog, error: .notFound, showingSnapshot: false),
        ])
    }

    @Test func retryLoadsAndThenReportsTheView() async {
        let viewModel = makeViewModel()
        repository.enqueueProduct(.failure(AppError.offline))
        await viewModel.start()
        analytics.reset()

        repository.enqueueProduct(.success(Self.mascara))
        viewModel.retry()
        await viewModel.retryTask?.value

        #expect(viewModel.refresh == .refreshed)
        #expect(viewModel.product == Self.mascara)
        #expect(analytics.events == [
            .retryRequested(failedSurface: .details, error: .offline),
            Self.viewedMascara,
        ])
    }

    // MARK: - Analytics

    /// D-81: sent when the full product arrives, with every property, once per push; the screen's
    /// appearance doesn't send it again.
    @Test func detailsViewedOnceTheFullProductArrives() async {
        let viewModel = makeViewModel()
        viewModel.contentAppeared()
        #expect(analytics.events.isEmpty, "nothing before the full product")

        repository.enqueueProduct(.success(Self.mascara))
        await viewModel.start()
        viewModel.contentAppeared()

        #expect(analytics.events == [Self.viewedMascara])
    }

    @Test func detailsViewedReportsMissingData() async {
        _ = await loadedViewModel(makeProduct(id: 2, discountPercentage: 0), source: .catalog)

        #expect(analytics.events == [
            .productDetailsViewed(productID: 2, source: .catalog, category: nil, availability: nil, hasDiscount: false, imageCount: 0, savedAt: nil, contentOrigin: .network),
        ])
    }

    /// A new push builds a new view model, so it reports its own view.
    @Test func eachPushTracksItsOwnView() async {
        _ = await loadedViewModel()
        _ = await loadedViewModel()

        #expect(analytics.events.count == 2)
    }

    @Test func galleryEventFiresOnceOnTheFirstSwipe() async {
        let viewModel = await loadedViewModel()
        analytics.reset()

        viewModel.galleryPageChanged(to: 0)
        #expect(analytics.events.isEmpty, "the image already shown is not a swipe")

        viewModel.galleryPageChanged(to: 1)
        viewModel.galleryPageChanged(to: 2)
        viewModel.galleryPageChanged(to: 0)

        #expect(analytics.events == [.productGalleryInteracted(productID: 1, imageCount: 3)])
        #expect(viewModel.galleryIndex == 0)
    }

    // MARK: - Saving (S5)

    /// `is_saved` comes from the store; the save date travels with the event for
    /// `saved_product_revisited` (D-64).
    @Test func detailsViewedReportsTheSavedDate() async {
        let savedAt = date("2026-11-10T10:00:00Z")
        let store = await loadedSavedStore([SavedProduct(summary: Self.mascara.summary, savedAt: savedAt)])

        _ = await loadedViewModel(store: store)

        #expect(analytics.events == [
            .productDetailsViewed(productID: 1, source: .search, category: "beauty", availability: .lowStock, hasDiscount: true, imageCount: 3, savedAt: savedAt, contentOrigin: .network),
        ])
    }

    /// Saving works before the full product arrives: the summary has every snapshot field.
    @Test func toolbarSaveAndUnsaveTrackDetailsSurface() async {
        let store = await loadedSavedStore(now: now.now)
        let viewModel = makeViewModel(store: store)

        viewModel.saveToggled()
        #expect(viewModel.isSaved)
        #expect(store.item(id: 1)?.summary == Self.mascara.summary)
        now.advance(by: 30)
        viewModel.saveToggled()

        #expect(!viewModel.isSaved)
        #expect(analytics.events == [
            .productSaved(productID: 1, surface: .details, category: "beauty", price: Self.mascara.price, position: nil, savedCountAfter: 1),
            .productUnsaved(productID: 1, surface: .details, savedDurationS: 30, savedCountAfter: 0),
        ])
    }

    /// AC-D3: saving on details shows on the catalog card at once; both read one store.
    @Test func saveOnDetailsUpdatesTheCatalogCard() async {
        let store = await loadedSavedStore()
        let catalog = CatalogViewModel(repository: FakeProductRepository(), analytics: SpyAnalytics(), router: Router(), savedProducts: store, cardExperiment: unobservedCardExperiment(), clock: TestClock())
        let viewModel = makeViewModel(store: store)

        viewModel.saveToggled()

        #expect(catalog.isSaved(1))
    }
}
