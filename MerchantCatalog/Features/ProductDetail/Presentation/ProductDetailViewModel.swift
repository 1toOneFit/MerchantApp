import Observation

/// The details screen's state and intents (ProductSpecification § 4.3).
///
/// Content comes from the product the list already loaded, so it is complete at once, with no
/// spinner and no request (AC-D1, Networking.md A7). Analytics go through `AnalyticsTracking` only:
/// `product_details_viewed` once per screen, which is once per push, and
/// `product_gallery_interacted` at the first swipe to another image (D-59).
@MainActor
@Observable
final class ProductDetailViewModel {
    let header: ProductDetailHeader
    let insights: ProductInsights
    let gallery: ProductGalleryModel
    /// The gallery image on screen.
    private(set) var galleryIndex = 0

    @ObservationIgnored private let route: ProductDetailRoute
    @ObservationIgnored private let analytics: any AnalyticsTracking
    @ObservationIgnored private var hasTrackedView = false
    @ObservationIgnored private var hasTrackedGallery = false

    init(route: ProductDetailRoute, analytics: any AnalyticsTracking) {
        self.route = route
        self.analytics = analytics
        header = ProductDetailHeader(route.product)
        insights = ProductInsights(route.product)
        gallery = ProductGalleryModel(route.product)
    }

    /// The details content appeared. Only the first appearance counts: tab switches and returning
    /// to the screen don't re-send (D-59).
    func contentAppeared() {
        guard !hasTrackedView else { return }
        hasTrackedView = true
        let product = route.product
        analytics.track(.productDetailsViewed(
            productID: product.id,
            source: route.source,
            category: product.category,
            availability: product.availability,
            hasDiscount: (product.discountPercentage ?? 0) > 0,
            imageCount: product.imageURLs.count,
            contentOrigin: .list
        ))
    }

    /// The gallery shows image `index`. The first change away from the image on screen is the
    /// visit's gallery interaction.
    func galleryPageChanged(to index: Int) {
        guard index != galleryIndex else { return }
        galleryIndex = index
        guard !hasTrackedGallery else { return }
        hasTrackedGallery = true
        analytics.track(.productGalleryInteracted(productID: route.product.id, imageCount: gallery.imageURLs.count))
    }
}
