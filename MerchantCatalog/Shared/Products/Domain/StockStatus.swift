/// How much of a product is left, from its stock count (D-84). The one policy every screen uses:
/// cards, Needs attention, details and the `availability` analytics property.
///
/// - `stock <= 0` → out of stock (the demo data has no negative stock; one would mean none left)
/// - `stock` in `1...lowStockLimit` → low stock
/// - `stock > lowStockLimit` → in stock
///
/// The API's own `availabilityStatus` isn't used: list pages don't select it, and it disagrees with
/// `stock` for some demo products (Networking.md A16).
enum StockStatus: Hashable, Sendable {
    case outOfStock
    case lowStock
    case inStock

    /// The highest stock that still counts as low.
    static let lowStockLimit = 10

    /// `nil` when the stock is unknown: no status is shown and the product never needs attention.
    init?(stock: Int?) {
        guard let stock else { return nil }
        switch stock {
        case ...0: self = .outOfStock
        case 1...Self.lowStockLimit: self = .lowStock
        default: self = .inStock
        }
    }

    /// Low or out of stock: the product is listed under Needs attention (D-85).
    var needsAttention: Bool {
        self != .inStock
    }
}
