/// Which products of the list on screen the grid shows (D-85).
enum CatalogScope: Equatable, Sendable {
    /// Every loaded product, in server order.
    case all
    /// Only the loaded products that are low or out of stock (`StockStatus.needsAttention`), in
    /// server order. No request of its own: the catalog has no inventory endpoint, so the scope can
    /// only look at what the list has loaded.
    case needsAttention
}

/// What the Needs attention count is based on: the products of the list loaded so far (D-85).
struct AttentionCoverage: Equatable, Sendable {
    /// Products of the list loaded (without duplicates).
    let loaded: Int
    /// Products in the whole list, as the last page reported.
    let total: Int
    /// Products of the list not received yet: what "Check more" can still look at.
    let remaining: Int
    /// No more pages: the count covers the whole list.
    let isComplete: Bool
}
