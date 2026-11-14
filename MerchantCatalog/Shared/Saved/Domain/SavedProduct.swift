import Foundation

/// A product the merchant saved: the very `ProductSummary` a list hands to details, plus when it was
/// saved (D-82). Enough for the Saved tab to render instantly and offline, and opening it from Saved
/// hands details the same piece of data as opening it from a list. It is the merchant's selection,
/// not current truth: details refetch the product (D-9). User data, not a cache (D-10).
struct SavedProduct: Identifiable, Hashable, Sendable {
    /// What was saved, as the list had it; its `price` is the price when saved. Never a stock count
    /// (D-89).
    let summary: ProductSummary
    let savedAt: Date

    /// Keeps every field of `summary` except the stock: the stock when saved would read as current
    /// offline, and the saved file has no field for it (D-89).
    init(summary: ProductSummary, savedAt: Date) {
        self.summary = ProductSummary(
            id: summary.id,
            title: summary.title,
            price: summary.price,
            thumbnailURL: summary.thumbnailURL,
            rating: summary.rating,
            category: summary.category
        )
        self.savedAt = savedAt
    }

    var id: ProductSummary.ID { summary.id }
}

extension SavedProduct {
    /// The snapshot as a product for the details screen: only the snapshot's facts (D-67).
    var displayProduct: Product {
        summary.displayProduct
    }
}
