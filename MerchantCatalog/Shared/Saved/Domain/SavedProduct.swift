import Foundation

/// A product the merchant saved: the very `ProductSummary` a list hands to details, plus when it was
/// saved (D-82). Enough for the Saved tab to render instantly and offline, and opening it from Saved
/// hands details the same piece of data as opening it from a list. It is the merchant's selection,
/// not current truth: details refetch the product (D-9). User data, not a cache (D-10).
struct SavedProduct: Identifiable, Hashable, Sendable {
    /// What was saved, as the list had it; its `price` is the price when saved.
    let summary: ProductSummary
    let savedAt: Date

    var id: ProductSummary.ID { summary.id }
}

extension SavedProduct {
    /// The snapshot as a product for the details screen: only the snapshot's facts (D-67).
    var displayProduct: Product {
        summary.displayProduct
    }
}
