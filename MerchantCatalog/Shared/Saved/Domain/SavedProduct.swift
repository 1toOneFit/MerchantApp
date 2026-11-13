import Foundation

/// A product the merchant saved, as a snapshot of what the Saved tab shows (ProductSpecification
/// § 4.4): enough to render instantly and offline. It is the merchant's selection, not current
/// truth: details refetch the product (D-9). User data, not a cache (D-10).
struct SavedProduct: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let thumbnailURL: URL?
    /// The price when saved.
    let price: Decimal
    let rating: Double?
    /// The API's category slug.
    let category: String?
    let savedAt: Date
}

extension SavedProduct {
    /// A snapshot of `product`, saved at `savedAt`.
    init(_ product: Product, savedAt: Date) {
        self.init(
            id: product.id,
            title: product.title,
            thumbnailURL: product.thumbnailURL,
            price: product.price,
            rating: product.rating,
            category: product.category,
            savedAt: savedAt
        )
    }

    /// The snapshot as a product for the details screen: only the snapshot's facts, so every other
    /// section is omitted (AC-D2). No gallery: the gallery never shows the thumbnail (D-67).
    var displayProduct: Product {
        Product(
            id: id,
            title: title,
            price: price,
            brand: nil,
            availability: nil,
            thumbnailURL: thumbnailURL,
            imageURLs: [],
            productDescription: nil,
            category: category,
            tags: [],
            rating: rating,
            discountPercentage: nil,
            stock: nil,
            sku: nil,
            weight: nil,
            dimensions: nil,
            warranty: nil,
            shipping: nil,
            returnPolicy: nil,
            minimumOrderQuantity: nil,
            reviews: []
        )
    }
}
