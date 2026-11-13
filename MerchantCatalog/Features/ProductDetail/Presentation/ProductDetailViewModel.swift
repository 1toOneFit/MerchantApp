import Foundation
import Observation

/// Where the refresh of details opened from Saved stands.
enum DetailRefreshState: Equatable {
    /// Not started, or cancelled (the next appearance starts it again). Details from a list stay
    /// here: they need no request (Networking.md A7).
    case idle
    case loading
    /// The fresh product replaced the snapshot.
    case refreshed
    /// The snapshot stays, with a banner and Retry.
    case failed(AppError)
    /// HTTP 404: the product is gone. The snapshot stays; no Retry (D-67).
    case unavailable
}

/// The details screen's state and intents (ProductSpecification § 4.3).
///
/// - From a list, the content is the list's product, complete at once with no request (AC-D1,
///   Networking.md A7).
/// - From Saved, the snapshot shows first and `/products/{id}` refreshes it: `start()` runs from the
///   view's `.task`, so leaving the screen cancels it. Retry runs from a tap, so the view model keeps
///   that task and cancels it when it goes away. A cancelled request applies nothing, even when its
///   response won the race. A failure keeps the snapshot (AC-D4). The stored snapshot is never
///   overwritten (D-67).
/// - The toolbar's save button toggles the shared store (AC-D3).
/// - Analytics go through `AnalyticsTracking` only: `product_details_viewed` once per screen, which
///   is once per push, and `product_gallery_interacted` at the first swipe to another image (D-59).
@MainActor
@Observable
final class ProductDetailViewModel {
    /// What the screen shows: the list's product, the snapshot, or the fresh product.
    private(set) var product: Product
    /// The gallery image on screen.
    private(set) var galleryIndex = 0
    private(set) var refresh: DetailRefreshState = .idle
    /// The Retry's request; tests await it.
    @ObservationIgnored private(set) var retryTask: Task<Void, Never>?

    @ObservationIgnored private let route: ProductDetailRoute
    @ObservationIgnored private let repository: any ProductRepository
    @ObservationIgnored private let savedProducts: SavedProductsStore
    @ObservationIgnored private let analytics: any AnalyticsTracking
    @ObservationIgnored private var hasTrackedView = false
    @ObservationIgnored private var hasTrackedGallery = false

    init(
        route: ProductDetailRoute,
        repository: any ProductRepository,
        savedProducts: SavedProductsStore,
        analytics: any AnalyticsTracking
    ) {
        self.route = route
        self.repository = repository
        self.savedProducts = savedProducts
        self.analytics = analytics
        product = switch route {
        case .list(let product, _): product
        case .saved(let snapshot): snapshot.displayProduct
        }
    }

    isolated deinit {
        retryTask?.cancel()
    }

    var header: ProductDetailHeader { ProductDetailHeader(product) }
    var insights: ProductInsights { ProductInsights(product) }
    var gallery: ProductGalleryModel { ProductGalleryModel(product) }

    /// The snapshot the screen opened with, for details opened from Saved.
    var savedSnapshot: SavedProduct? {
        if case .saved(let snapshot) = route { snapshot } else { nil }
    }

    /// The saved snapshot is on screen (the fresh product hasn't replaced it).
    var isShowingSnapshot: Bool {
        savedSnapshot != nil && refresh != .refreshed
    }

    /// The price when saved, once the fresh product shows a different one ("Price changed since you
    /// saved it", ProductSpecification § 4.4).
    var savedPriceIfChanged: Decimal? {
        guard refresh == .refreshed, let savedSnapshot, savedSnapshot.price != product.price else { return nil }
        return savedSnapshot.price
    }

    var isSaved: Bool {
        savedProducts.isSaved(product.id)
    }

    // MARK: - Intents

    /// Refreshes details opened from Saved; does nothing for details from a list, or once the
    /// refresh has run. Called from the view's `.task`.
    func start() async {
        guard savedSnapshot != nil, refresh == .idle else { return }
        refresh = .loading
        let result = await Self.fetch(product.id, from: repository)
        finishRefresh(Task.isCancelled ? .failure(CancellationError()) : result)
    }

    /// The banner's Retry after a failed refresh.
    func retry() {
        guard case .failed(let error) = refresh else { return }
        analytics.track(.retryRequested(failedSurface: .details, error: error))
        refresh = .loading
        let id = product.id
        let repository = repository
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            let result = await Self.fetch(id, from: repository)
            self?.finishRefresh(Task.isCancelled ? .failure(CancellationError()) : result)
        }
    }

    /// The toolbar's save button: saves the product on screen (a snapshot re-saves its own fields)
    /// or removes it.
    func saveToggled() {
        let change = savedProducts.isSaved(product.id)
            ? savedProducts.remove(id: product.id)
            : savedProducts.save(product)
        if let change {
            analytics.track(change.event(surface: .details, position: nil))
        }
    }

    /// The details content appeared. Only the first appearance counts: tab switches and returning
    /// to the screen don't re-send (D-59). From Saved, the snapshot is what appeared (D-63).
    func contentAppeared() {
        guard !hasTrackedView else { return }
        hasTrackedView = true
        let fromSnapshot = savedSnapshot != nil
        analytics.track(.productDetailsViewed(
            productID: product.id,
            source: route.source,
            category: product.category,
            availability: fromSnapshot ? nil : product.availability,
            hasDiscount: fromSnapshot ? nil : (product.discountPercentage ?? 0) > 0,
            imageCount: fromSnapshot ? nil : product.imageURLs.count,
            savedAt: savedProducts.item(id: product.id)?.savedAt,
            contentOrigin: fromSnapshot ? .snapshot : .list
        ))
    }

    /// The gallery shows image `index`. The first change away from the image on screen is the
    /// visit's gallery interaction.
    func galleryPageChanged(to index: Int) {
        guard index != galleryIndex else { return }
        galleryIndex = index
        guard !hasTrackedGallery else { return }
        hasTrackedGallery = true
        analytics.track(.productGalleryInteracted(productID: product.id, imageCount: gallery.imageURLs.count))
    }

    // MARK: - Refresh

    private func finishRefresh(_ result: Result<Product, any Error>) {
        switch result {
        case .success(let fresh):
            product = fresh
            refresh = .refreshed
        case .failure(let error) where error is CancellationError:
            refresh = .idle
        case .failure(let error):
            let appError = error as? AppError ?? .unknown
            refresh = appError == .notFound ? .unavailable : .failed(appError)
            analytics.track(.productDetailsLoadFailed(
                productID: product.id,
                source: route.source,
                error: appError,
                showingSnapshot: isShowingSnapshot
            ))
        }
    }

    /// The product's fresh data, without referencing the view model.
    private static func fetch(_ id: Product.ID, from repository: any ProductRepository) async -> Result<Product, any Error> {
        do {
            return .success(try await repository.product(id: id))
        } catch {
            return .failure(error)
        }
    }
}
