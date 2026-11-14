import Foundation
import Observation

/// Where the request for the full product (`/products/{id}`) stands (D-83).
enum DetailLoadState: Equatable {
    /// Not started, or cancelled (the next appearance starts it again).
    case idle
    case loading
    case loaded
    /// Retry is offered.
    case failed(AppError)
    /// HTTP 404: the product is gone; no Retry (D-67).
    case unavailable
}

/// What the details screen shows.
enum DetailScreen: Equatable {
    /// Every part of the screen as a placeholder, until the full product arrives.
    case skeleton
    /// The full product, or, from Saved after a failed request, the saved snapshot's facts.
    case content(Product)
    /// No product to show: a full-screen error (`.notFound`: no longer available, without Retry).
    case failed(AppError)
}

/// The details screen's state and intents (ProductSpecification § 4.3).
///
/// - Opened by id from any source (D-83): a skeleton until `/products/{id}` returns the full product.
///   `start()` runs from the view's `.task`, so leaving the screen cancels it. Retry runs from a tap,
///   so the view model keeps that task and cancels it when it goes away. A cancelled request applies
///   nothing, even when its response won the race.
/// - From Saved, the saved snapshot is looked up in the store when the screen opens. A failed request
///   falls back to it with a banner (AC-D4); after a success, a different price is pointed out
///   against it. The stored snapshot is never overwritten (D-67). From the catalog or search, a
///   failure is a full-screen error.
/// - The toolbar's save button toggles the shared store (AC-D3); saving waits for the product's data,
///   removing doesn't.
/// - Analytics go through `AnalyticsTracking` only: `product_details_viewed` once per screen, when
///   content first shows (the full product, or Saved's snapshot fallback, D-83), and
///   `product_gallery_interacted` at the first swipe to another image (D-59).
@MainActor
@Observable
final class ProductDetailViewModel {
    /// The full product, once `/products/{id}` returned it.
    private(set) var product: Product?
    private(set) var load: DetailLoadState = .idle
    /// The gallery image on screen.
    private(set) var galleryIndex = 0
    /// The Retry's request; tests await it.
    @ObservationIgnored private(set) var retryTask: Task<Void, Never>?
    /// From Saved: the snapshot in the store when the screen opened.
    let savedSnapshot: SavedProduct?

    @ObservationIgnored private let route: ProductDetailRoute
    @ObservationIgnored private let repository: any ProductRepository
    @ObservationIgnored private let savedProducts: SavedProductsStore
    @ObservationIgnored private let analytics: any AnalyticsTracking
    @ObservationIgnored private var hasTrackedView = false
    @ObservationIgnored private var hasTrackedGallery = false
    /// A request failed on this screen: from Saved, the snapshot stays on screen from then on, also
    /// while a Retry runs.
    private var hasFailed = false
    /// The failure a running Retry started from; a cancelled Retry returns to it.
    @ObservationIgnored private var failureBeforeRetry: DetailLoadState?

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
        savedSnapshot = route.source == .saved ? savedProducts.item(id: route.productID) : nil
    }

    isolated deinit {
        retryTask?.cancel()
    }

    // MARK: - State

    var screen: DetailScreen {
        if let product { return .content(product) }
        if let snapshot = savedSnapshot, isShowingSnapshot { return .content(snapshot.displayProduct) }
        return switch load {
        case .idle, .loading, .loaded: .skeleton
        case .failed(let error): .failed(error)
        case .unavailable: .failed(.notFound)
        }
    }

    /// From Saved: a request failed and the snapshot is what the screen shows.
    var isShowingSnapshot: Bool {
        product == nil && savedSnapshot != nil && hasFailed
    }

    /// The product the layout is built from: what `screen` shows, or a placeholder for the skeleton.
    private var shownProduct: Product {
        if case .content(let product) = screen { product } else { .detailPlaceholder }
    }

    var header: ProductDetailHeader { ProductDetailHeader(shownProduct) }
    var insights: ProductInsights { ProductInsights(shownProduct) }
    var gallery: ProductGalleryModel { ProductGalleryModel(shownProduct) }

    /// The status over Saved's snapshot fallback, or `nil`.
    var statusMessage: String? {
        guard isShowingSnapshot else { return nil }
        return switch load {
        case .unavailable: AppError.notFound.userMessage
        case .loading: "Updating…"
        case .idle, .loaded, .failed: "Couldn't refresh — showing saved info"
        }
    }

    /// The price when saved, once the fresh product shows a different one ("Price changed since you
    /// saved it", ProductSpecification § 4.4).
    var savedPriceIfChanged: Decimal? {
        guard let product, let savedSnapshot, savedSnapshot.summary.price != product.price else { return nil }
        return savedSnapshot.summary.price
    }

    var isSaved: Bool {
        savedProducts.isSaved(route.productID)
    }

    /// Saving needs the product's data (the full product or Saved's fallback); removing doesn't.
    var canToggleSave: Bool {
        isSaved || savedSummary != nil
    }

    private var savedSummary: ProductSummary? {
        if case .content(let product) = screen { product.summary } else { nil }
    }

    // MARK: - Intents

    /// Loads the full product; does nothing once the request has run. Called from the view's
    /// `.task`, so a cancelled load (the screen left) runs again at the next appearance.
    func start() async {
        guard load == .idle else { return }
        load = .loading
        let result = await Self.fetch(route.productID, from: repository)
        finishLoad(Task.isCancelled ? .failure(CancellationError()) : result)
    }

    /// Retry after a failed request (the error screen or Saved's banner).
    func retry() {
        guard case .failed(let error) = load else { return }
        analytics.track(.retryRequested(failedSurface: .details, error: error))
        failureBeforeRetry = load
        load = .loading
        let id = route.productID
        let repository = repository
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            let result = await Self.fetch(id, from: repository)
            self?.finishLoad(Task.isCancelled ? .failure(CancellationError()) : result)
        }
    }

    /// The toolbar's save button: saves what the screen shows, or removes the product.
    func saveToggled() {
        let change: SavedProductsChange?
        if savedProducts.isSaved(route.productID) {
            change = savedProducts.remove(id: route.productID)
        } else if let summary = savedSummary {
            change = savedProducts.save(summary)
        } else {
            change = nil
        }
        if let change {
            analytics.track(change.event(surface: .details, position: nil))
        }
    }

    /// The gallery shows image `index`. The first change away from the image on screen is the
    /// visit's gallery interaction.
    func galleryPageChanged(to index: Int) {
        guard index != galleryIndex else { return }
        galleryIndex = index
        guard !hasTrackedGallery else { return }
        hasTrackedGallery = true
        analytics.track(.productGalleryInteracted(productID: route.productID, imageCount: gallery.imageURLs.count))
    }

    // MARK: - Load

    private func finishLoad(_ result: Result<Product, any Error>) {
        defer { failureBeforeRetry = nil }
        switch result {
        case .success(let fresh):
            product = fresh
            load = .loaded
            trackViewIfNeeded(fresh, origin: .network)
        case .failure(let error) where error is CancellationError:
            load = failureBeforeRetry ?? .idle
        case .failure(let error):
            let appError = error as? AppError ?? .unknown
            hasFailed = true
            load = appError == .notFound ? .unavailable : .failed(appError)
            analytics.track(.productDetailsLoadFailed(
                productID: route.productID,
                source: route.source,
                error: appError,
                showingSnapshot: savedSnapshot != nil
            ))
            if let savedSnapshot {
                trackViewIfNeeded(savedSnapshot.displayProduct, origin: .snapshot)
            }
        }
    }

    /// `product_details_viewed` once per screen, when content first shows: every property for the
    /// full product, the snapshot's facts for Saved's fallback (D-63, D-83).
    private func trackViewIfNeeded(_ shown: Product, origin: ContentOrigin) {
        guard !hasTrackedView else { return }
        hasTrackedView = true
        let fromSnapshot = origin == .snapshot
        analytics.track(.productDetailsViewed(
            productID: shown.id,
            source: route.source,
            category: shown.category,
            availability: fromSnapshot ? nil : shown.availability,
            hasDiscount: fromSnapshot ? nil : (shown.discountPercentage ?? 0) > 0,
            imageCount: fromSnapshot ? nil : shown.imageURLs.count,
            savedAt: savedProducts.item(id: shown.id)?.savedAt,
            contentOrigin: origin
        ))
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

extension Product {
    /// What the skeleton lays out: a product with every section present, so each part of the screen
    /// has its placeholder shape. Never shown as text: the view redacts it.
    static let detailPlaceholder = Product(
        id: 0,
        title: "Product name placeholder",
        price: 99.99,
        brand: "Brand name",
        availability: .inStock,
        thumbnailURL: nil,
        imageURLs: [],
        productDescription: "A placeholder description that spans about two lines of text on a phone screen.",
        category: "category",
        tags: ["tag", "tag"],
        rating: 4.5,
        discountPercentage: 10,
        stock: 10,
        sku: "SKU-0000",
        weight: 1,
        dimensions: ProductDimensions(width: 10, height: 10, depth: 10),
        warranty: "Warranty placeholder",
        shipping: "Shipping placeholder",
        returnPolicy: "Return policy placeholder",
        minimumOrderQuantity: 1,
        reviews: (0..<2).map { _ in
            ProductReview(rating: 5, comment: "A placeholder review comment.", reviewerName: "Reviewer name", date: nil)
        }
    )
}
