import Foundation
import Testing
@testable import MerchantCatalog

/// The details gallery (ProductSpecification § 4.3 item 1).
struct ProductGalleryModelTests {
    private static let images = (1...3).compactMap { URL(string: "https://cdn.dummyjson.com/products/1/\($0).webp") }

    /// The gallery loads the full images, never the card thumbnail.
    @Test func galleryUsesFullImages() {
        let gallery = ProductGalleryModel(makeProduct(id: 1, imageURLs: Self.images))

        #expect(gallery.imageURLs == Self.images)
        #expect(gallery.showsPageIndicator)
    }

    @Test func singleImageHidesThePageIndicator() {
        let gallery = ProductGalleryModel(makeProduct(id: 1, imageURLs: [Self.images[0]]))

        #expect(gallery.imageURLs == [Self.images[0]])
        #expect(!gallery.showsPageIndicator)
    }

    @Test func noImagesMeansEmptyGallery() {
        let gallery = ProductGalleryModel(makeProduct(id: 1))

        #expect(gallery.imageURLs.isEmpty)
        #expect(!gallery.showsPageIndicator)
    }
}
