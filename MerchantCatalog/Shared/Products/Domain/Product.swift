import Foundation

/// A catalog product as the app uses it: what the card needs (S2, D-37) plus the details fields
/// (S4). Everything the API may omit is optional or empty, so the details screen can leave out a
/// fact the data doesn't have (ProductSpecification § 4.3). `Hashable` so a details route can carry
/// it (D-57).
struct Product: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    /// Demo price in USD, shown as "Price" (no discounted price is computed, D-11).
    let price: Decimal
    /// `nil` for the many products without a brand (Networking.md A10).
    let brand: String?
    let thumbnailURL: URL?
    /// Gallery images, in API order.
    let imageURLs: [URL]

    // MARK: Details (S4)

    let productDescription: String?
    /// The API's category slug, e.g. `mens-shirts`.
    let category: String?
    let tags: [String]
    /// The API's aggregate rating; not derived from `reviews` (ProductSpecification § 6).
    let rating: Double?
    /// As the API provides it; whether `price` is before or after it is undocumented (D-11).
    let discountPercentage: Double?
    let stock: Int?
    let sku: String?
    /// No unit is given by the API (Networking.md A14).
    let weight: Double?
    let dimensions: ProductDimensions?
    let warranty: String?
    let shipping: String?
    let returnPolicy: String?
    let minimumOrderQuantity: Int?
    /// The few recent reviews the API returns (3 per demo product, A10).
    let reviews: [ProductReview]
}

extension Product {
    /// From `stock` by the one policy (D-84); `nil` when the stock is unknown.
    var stockStatus: StockStatus? {
        StockStatus(stock: stock)
    }
}

/// Width, height and depth as the API gives them, without units (Networking.md A14).
struct ProductDimensions: Hashable, Sendable {
    let width: Double
    let height: Double
    let depth: Double
}

/// One of a product's recent reviews. The reviewer's email is never part of it.
struct ProductReview: Hashable, Sendable {
    /// 1–5.
    let rating: Int?
    let comment: String?
    let reviewerName: String?
    let date: Date?
}
