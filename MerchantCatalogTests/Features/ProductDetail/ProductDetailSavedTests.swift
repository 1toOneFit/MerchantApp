import Foundation
import Testing
@testable import MerchantCatalog

/// Details opened from Saved (ProductSpecification § 4.3, § 4.4; AC-D4; D-83): opened by id, a
/// skeleton until `/products/{id}` returns. A failure falls back to the saved snapshot from the store
/// with a banner and Retry; a 404 says the product is no longer available; a different fresh price is
/// pointed out. The stored snapshot never changes (D-67).
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductDetailSavedTests {
    private let analytics = SpyAnalytics()
    private let repository = FakeProductRepository()
    private let now = TestNow()

    private static let savedAt = date("2026-11-10T10:00:00Z")
    private static let snapshot = SavedProduct(
        summary: ProductSummary(
            id: 1,
            title: "Volume Mascara",
            price: Decimal(string: "9.99")!,
            thumbnailURL: URL(string: "https://cdn.dummyjson.com/products/1/thumbnail.webp"),
            rating: 4.94,
            category: "beauty"
        ),
        savedAt: savedAt
    )
    private static let images = (1...3).compactMap { URL(string: "https://cdn.dummyjson.com/products/1/\($0).webp") }

    private static func fresh(price: String = "9.99") -> Product {
        makeProduct(
            id: 1,
            title: "Volume Mascara",
            price: Decimal(string: price),
            brand: "Acme",
            imageURLs: images,
            category: "beauty",
            rating: 4.94,
            discountPercentage: 7.17,
            stock: 5
        )
    }

    private func makeViewModel(store: SavedProductsStore) -> ProductDetailViewModel {
        ProductDetailViewModel(route: ProductDetailRoute(productID: 1, source: .saved), repository: repository, savedProducts: store, analytics: analytics)
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

    private static let viewedFresh = AnalyticsEvent.productDetailsViewed(
        productID: 1, source: .saved, category: "beauty", availability: .lowStock, hasDiscount: true, imageCount: 3, savedAt: savedAt, contentOrigin: .network
    )
    private static let viewedSnapshot = AnalyticsEvent.productDetailsViewed(
        productID: 1, source: .saved, category: "beauty", availability: nil, hasDiscount: nil, imageCount: nil, savedAt: savedAt, contentOrigin: .snapshot
    )

    /// D-83: opened by id, the skeleton shows first; the snapshot is found in the store, kept for a
    /// failure and the price note.
    @Test func savedRouteStartsWithTheSkeleton() async {
        let viewModel = makeViewModel(store: await savedStore())

        #expect(viewModel.screen == .skeleton)
        #expect(viewModel.savedSnapshot == Self.snapshot)
        #expect(!viewModel.isShowingSnapshot)
        #expect(viewModel.statusMessage == nil)
        #expect(viewModel.load == .idle)
        #expect(repository.productRequests.isEmpty)
        #expect(analytics.events.isEmpty)
    }

    @Test func loadShowsTheFullProductAndReportsTheView() async {
        let viewModel = makeViewModel(store: await savedStore())
        repository.enqueueProduct(.success(Self.fresh()))

        await viewModel.start()

        #expect(repository.productRequests == [1])
        #expect(viewModel.load == .loaded)
        #expect(viewModel.screen == .content(Self.fresh()))
        #expect(viewModel.gallery.imageURLs == Self.images)
        #expect(!viewModel.isShowingSnapshot)
        #expect(viewModel.savedPriceIfChanged == nil)
        #expect(analytics.events == [Self.viewedFresh])
    }

    @Test func skeletonWhileLoading() async {
        let viewModel = makeViewModel(store: await savedStore())
        let start = Task { await viewModel.start() }
        await repository.waitForPendingProductRequests(1)

        #expect(viewModel.load == .loading)
        #expect(viewModel.screen == .skeleton)
        #expect(viewModel.statusMessage == nil)

        repository.resumeNextProduct(with: .success(Self.fresh()))
        await start.value
        #expect(viewModel.load == .loaded)
    }

    @Test func priceChangeIsReported() async {
        let viewModel = makeViewModel(store: await savedStore())
        repository.enqueueProduct(.success(Self.fresh(price: "12.49")))

        await viewModel.start()

        #expect(viewModel.savedPriceIfChanged == Decimal(string: "9.99"))
    }

    /// AC-D4: offline, the snapshot from the store shows with the refresh-failed banner, and that
    /// is the view (offline revisits keep counting, D-64).
    @Test func failureFallsBackToTheSnapshot() async {
        let viewModel = makeViewModel(store: await savedStore())
        repository.enqueueProduct(.failure(AppError.offline))

        await viewModel.start()

        #expect(viewModel.load == .failed(.offline))
        #expect(viewModel.isShowingSnapshot)
        #expect(viewModel.screen == .content(Self.snapshot.displayProduct))
        #expect(viewModel.statusMessage == "Couldn't refresh — showing saved info")
        #expect(analytics.events == [
            .productDetailsLoadFailed(productID: 1, source: .saved, error: .offline, showingSnapshot: true),
            Self.viewedSnapshot,
        ])
    }

    /// Unsaved meanwhile: no snapshot to fall back on, so the error shows as from a list.
    @Test func withoutASnapshotTheErrorShows() async {
        let viewModel = makeViewModel(store: await loadedSavedStore(now: now.now))
        repository.enqueueProduct(.failure(AppError.offline))

        await viewModel.start()

        #expect(viewModel.screen == .failed(.offline))
        #expect(analytics.events == [.productDetailsLoadFailed(productID: 1, source: .saved, error: .offline, showingSnapshot: false)])
    }

    @Test func retryTracksAndRefetches() async {
        let viewModel = await failedViewModel(.offline, store: await savedStore())
        repository.enqueueProduct(.success(Self.fresh()))

        viewModel.retry()
        #expect(viewModel.load == .loading)
        await viewModel.retryTask?.value

        #expect(analytics.events == [.retryRequested(failedSurface: .details, error: .offline)])
        #expect(repository.productRequests == [1, 1])
        #expect(viewModel.load == .loaded)
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
        #expect(viewModel.load == .failed(.timeout))
    }

    /// A 404 (A6) is final: "no longer available", no Retry, the snapshot stays.
    @Test func notFoundShowsUnavailable() async {
        let viewModel = makeViewModel(store: await savedStore())
        repository.enqueueProduct(.failure(AppError.notFound))

        await viewModel.start()
        viewModel.retry()

        #expect(viewModel.load == .unavailable)
        #expect(viewModel.isShowingSnapshot)
        #expect(viewModel.statusMessage == AppError.notFound.userMessage)
        #expect(analytics.events == [
            .productDetailsLoadFailed(productID: 1, source: .saved, error: .notFound, showingSnapshot: true),
            Self.viewedSnapshot,
        ])
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

        #expect(viewModel.load == .idle)
        #expect(analytics.events.isEmpty)

        repository.enqueueProduct(.success(Self.fresh()))
        await viewModel.start()
        #expect(viewModel.load == .loaded)
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

        #expect(viewModel.load == .idle)
        #expect(viewModel.screen == .skeleton)
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

        #expect(viewModel.load != .loaded)
        #expect(viewModel.screen == .content(Self.snapshot.displayProduct))
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

        let resaved = SavedProduct(summary: Self.snapshot.summary, savedAt: now.date)
        #expect(store.items == [resaved])
        #expect(viewModel.isSaved)
    }
}
