import Foundation

/// A catalog product as the app uses it. S2 holds what the catalog card needs plus the fields its
/// mapping tests pin (D-37); S4 adds the details fields.
struct Product: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    /// Demo price in USD, shown as "Price" (no discounted price is computed, D-11).
    let price: Decimal
    /// `nil` for the many products without a brand (Networking.md A10).
    let brand: String?
    /// `nil` when the API sends a value the app doesn't know.
    let availability: ProductAvailability?
    let thumbnailURL: URL?
    /// Gallery images, in API order.
    let imageURLs: [URL]
}

/// `availabilityStatus` values the API sends (Networking.md A10).
enum ProductAvailability: Equatable, Sendable {
    case inStock
    case lowStock
    case outOfStock
}
