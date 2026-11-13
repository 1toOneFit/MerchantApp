import Foundation
import Testing
@testable import MerchantCatalog

/// Details opened from Saved (ProductSpecification § 4.3, § 4.4; AC-D4): the snapshot first, then
/// `/products/{id}`. A failure keeps the snapshot with a banner and Retry; a 404 says the product is
/// no longer available; a different fresh price is pointed out. The stored snapshot never changes
/// (D-67).
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductDetailSavedTests {
    private let analytics = SpyAnalytics()
    private let repository = FakeProductRepository()
    private let now = TestNow()

    private static let savedAt = date("2026-11-10T10:00:00Z")
    private static let snapshot = SavedProduct(
        id: 1,
        title: "Volume Mascara",
        thumbnailURL: URL(string: "https://cdn.dummyjson.com/products/1/thumbnail.webp"),
        price: Decimal(string: "9.99")!,
        rating: 4.94,
        category: "beauty",
        savedAt: savedAt
    )
    private static let images = (1...3).compactMap { URL(string: "https://cdn.dummyjson.com/products/1/\($0).webp") }

    private static func fresh(price: String = "9.99") -> Product {
        makeProduct(
            id: 1,
            title: "Volume Mascara",
            price: Decimal(string: price),
            brand: "Acme",
            availability: .lowStock,
            imageURLs: images,
            category: "beauty",
            rating: 4.94,
            discountPercentage: 7.17
        )
    }

    private func makeViewModel(store: SavedProductsStore) -> ProductDetailViewModel {
        ProductDetailViewModel(route: .saved(Self.snapshot), repository: repository, savedProducts: store, analytics: analytics)
    }

    private func savedStore() async -> SavedProductsStore {
        await loadedSavedStore([Self.snapshot], now: now.now)
    }

    /// A view model whose first refresh failed with `error`, analytics cleared.
    private func failedViewModel(_ error: AppError, store: SavedProductsStore) async -> ProductDetailViewModel {
        let viewModel = makeViewModel(store: store)
        repository.enqueueProduct(.failure(error))
        await viewModel.start()
        analytics.reset()
        return viewModel
    }

    @Test func savedRouteShowsTheSnapshotFirst() async {
        let viewModel = makeViewModel(store: await savedStore())

        #expect(viewModel.product == Self.snapshot.displayProduct)
        #expect(viewModel.header == ProductDetailHeader(title: "Volume Mascara", brand: nil, category: "Beauty"))
        #expect(viewModel.insights.pricing == [.price(Decimal(string: "9.99")!)])
        #expect(viewModel.gallery.imageURLs.isEmpty)
        #expect(viewModel.isShowingSnapshot)
        #expect(viewModel.savedSnapshot == Self.snapshot)
        #expect(viewModel.refresh == .idle)
        #expect(repository.productRequests.isEmpty)
    }

    /// D-63: from Saved, the event describes the snapshot.
    @Test func savedRouteViewedEventUsesTheSnapshot() async {
        let viewModel = makeViewModel(store: await savedStore())

        viewModel.contentAppeared()

        #expect(analytics.events == [
            .productDetailsViewed(productID: 1, source: .saved, category: "beauty", availability: nil, hasDiscount: nil, imageCount: nil, savedAt: Self.savedAt, contentOrigin: .snapshot),
        ])
    }

    @Test func refreshReplacesTheSnapshot() async {
        let viewModel = makeViewModel(store: await savedStore())
        repository.enqueueProduct(.success(Self.fresh()))

        await viewModel.start()

        #expect(repository.productRequests == [1])
        #expect(viewModel.refresh == .refreshed)
        #expect(viewModel.product == Self.fresh())
        #expect(viewModel.gallery.imageURLs == Self.images)
        #expect(!viewModel.isShowingSnapshot)
        #expect(viewModel.savedPriceIfChanged == nil)
        #expect(analytics.events.isEmpty)
    }

    @Test func refreshIsLoadingWhileInFlight() async {
        let viewModel = makeViewModel(store: await savedStore())
        let start = Task { await viewModel.start() }
        await repository.waitForPendingProductRequests(1)

        #expect(viewModel.refresh == .loading)

        repository.resumeNextProduct(with: .success(Self.fresh()))
        await start.value
        #expect(viewModel.refresh == .refreshed)
    }

    @Test func priceChangeIsReported() async {
        let viewModel = makeViewModel(store: await savedStore())
        repository.enqueueProduct(.success(Self.fresh(price: "12.49")))

        await viewModel.start()

        #expect(viewModel.savedPriceIfChanged == Decimal(string: "9.99"))
    }

    /// AC-D4: offline, the snapshot stays with the refresh-failed banner.
    @Test func refreshFailureKeepsTheSnapshot() async {
        let viewModel = makeViewModel(store: await savedStore())
        repository.enqueueProduct(.failure(AppError.offline))

        await viewModel.start()

        #expect(viewModel.refresh == .failed(.offline))
        #expect(viewModel.isShowingSnapshot)
        #expect(viewModel.product == Self.snapshot.displayProduct)
        #expect(analytics.events == [.productDetailsLoadFailed(productID: 1, source: .saved, error: .offline, showingSnapshot: true)])
    }

    @Test func retryTracksAndRefetches() async {
        let viewModel = await failedViewModel(.offline, store: await savedStore())
        repository.enqueueProduct(.success(Self.fresh()))

        viewModel.retry()
        #expect(viewModel.refresh == .loading)
        await viewModel.retryTask?.value

        #expect(analytics.events == [.retryRequested(failedSurface: .details, error: .offline)])
        #expect(repository.productRequests == [1, 1])
        #expect(viewModel.refresh == .refreshed)
    }

    @Test func failedRetryReportsAgain() async {
        let viewModel = await failedViewModel(.offline, store: await savedStore())
        repository.enqueueProduct(.failure(AppError.timeout))

        viewModel.retry()
        await viewModel.retryTask?.value

        #expect(analytics.events == [
            .retryRequested(failedSurface: .details, error: .offline),
            .productDetailsLoadFailed(productID: 1, source: .saved, error: .timeout, showingSnapshot: true),
        ])
        #expect(viewModel.refresh == .failed(.timeout))
    }

    /// A 404 (A6) is final: "no longer available", no Retry, the snapshot stays.
    @Test func notFoundShowsUnavailable() async {
        let viewModel = makeViewModel(store: await savedStore())
        repository.enqueueProduct(.failure(AppError.notFound))

        await viewModel.start()
        viewModel.retry()

        #expect(viewModel.refresh == .unavailable)
        #expect(viewModel.isShowingSnapshot)
        #expect(analytics.events == [.productDetailsLoadFailed(productID: 1, source: .saved, error: .notFound, showingSnapshot: true)])
        #expect(repository.productRequests == [1])
    }

    /// Review Focus 3: leaving while the refresh runs is no failure; the next appearance tries again.
    @Test func cancelledRefreshChangesNothing() async {
        let viewModel = makeViewModel(store: await savedStore())
        let start = Task { await viewModel.start() }
        await repository.waitForPendingProductRequests(1)

        start.cancel()
        repository.resumeNextProduct(with: .failure(CancellationError()))
        await start.value

        #expect(viewModel.refresh == .idle)
        #expect(analytics.events.isEmpty)

        repository.enqueueProduct(.success(Self.fresh()))
        await viewModel.start()
        #expect(viewModel.refresh == .refreshed)
    }

    /// Review finding 1: the response arrives after the screen's task was cancelled. Cancellation
    /// wins: no fresh product, no state change, no event.
    @Test func cancellationWinsOverALateSuccess() async {
        let viewModel = makeViewModel(store: await savedStore())
        let start = Task { await viewModel.start() }
        await repository.waitForPendingProductRequests(1)

        start.cancel()
        repository.resumeNextProduct(with: .success(Self.fresh(price: "12.49")))
        await start.value

        #expect(viewModel.refresh == .idle)
        #expect(viewModel.product == Self.snapshot.displayProduct)
        #expect(viewModel.isShowingSnapshot)
        #expect(analytics.events.isEmpty)
    }

    /// The same race for the banner's Retry: a cancelled retry applies nothing.
    @Test func cancelledRetryIgnoresALateSuccess() async {
        let viewModel = await failedViewModel(.offline, store: await savedStore())
        viewModel.retry()
        await repository.waitForPendingProductRequests(1)

        viewModel.retryTask?.cancel()
        repository.resumeNextProduct(with: .success(Self.fresh(price: "12.49")))
        await viewModel.retryTask?.value

        #expect(viewModel.refresh != .refreshed)
        #expect(viewModel.product == Self.snapshot.displayProduct)
        #expect(analytics.events == [.retryRequested(failedSurface: .details, error: .offline)])
    }

    @Test func startFetchesOnce() async {
        let viewModel = makeViewModel(store: await savedStore())
        repository.enqueueProduct(.success(Self.fresh()))
        await viewModel.start()

        await viewModel.start()

        #expect(repository.productRequests == [1])
    }

    /// The retry's request doesn't outlive the screen.
    @Test func leavingTheScreenCancelsTheRetry() async {
        var viewModel: ProductDetailViewModel? = await failedViewModel(.offline, store: await savedStore())
        viewModel?.retry()
        let retry = viewModel?.retryTask
        await repository.waitForPendingProductRequests(1)

        viewModel = nil
        repository.resumeNextProduct(with: .failure(AppError.offline))
        await retry?.value

        #expect(repository.cancelledRequestCount == 1)
        #expect(analytics.events == [.retryRequested(failedSurface: .details, error: .offline)])
    }

    /// "Price when saved" stays the price when saved.
    @Test func snapshotIsNotOverwritten() async {
        let store = await savedStore()
        let viewModel = makeViewModel(store: store)
        repository.enqueueProduct(.success(Self.fresh(price: "12.49")))

        await viewModel.start()

        #expect(store.item(id: 1) == Self.snapshot)
    }

    /// Review Focus 4: unsave, then save again while only the snapshot is known.
    @Test func resavingFromTheSnapshotKeepsItsFields() async {
        let store = await savedStore()
        let viewModel = makeViewModel(store: store)
        repository.enqueueProduct(.failure(AppError.offline))
        await viewModel.start()

        viewModel.saveToggled()
        now.advance(by: 60)
        viewModel.saveToggled()

        let resaved = SavedProduct(
            id: 1,
            title: Self.snapshot.title,
            thumbnailURL: Self.snapshot.thumbnailURL,
            price: Self.snapshot.price,
            rating: Self.snapshot.rating,
            category: Self.snapshot.category,
            savedAt: now.date
        )
        #expect(store.items == [resaved])
        #expect(viewModel.isSaved)
    }
}
