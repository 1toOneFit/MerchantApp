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
    /// A snapshot of a list item or of the product on the details screen (`Product.summary`),
    /// saved at `savedAt`.
    init(_ summary: ProductSummary, savedAt: Date) {
        self.init(
            id: summary.id,
            title: summary.title,
            thumbnailURL: summary.thumbnailURL,
            price: summary.price,
            rating: summary.rating,
            category: summary.category,
            savedAt: savedAt
        )
    }

    /// The snapshot's fields as a list item has them.
    var summary: ProductSummary {
        ProductSummary(id: id, title: title, price: price, thumbnailURL: thumbnailURL, rating: rating, category: category)
    }

    /// The snapshot as a product for the details screen: only the snapshot's facts (D-67).
    var displayProduct: Product {
        summary.displayProduct
    }
}
