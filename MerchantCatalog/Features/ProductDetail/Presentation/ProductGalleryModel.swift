import Foundation

/// The details gallery: the product's full images in API order, never the card thumbnail. Each page
/// loads only while visible (`ProductImageView`, Networking.md § 4). No images: no gallery (AC-D2).
struct ProductGalleryModel: Equatable {
    let imageURLs: [URL]

    init(_ product: Product) {
        imageURLs = product.imageURLs
    }

    /// The page indicator is hidden when there is one image (ProductSpecification § 4.3).
    var showsPageIndicator: Bool {
        imageURLs.count > 1
    }
}
