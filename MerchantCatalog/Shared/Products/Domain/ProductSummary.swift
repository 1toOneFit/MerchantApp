import Foundation

/// A product as a list shows it (D-81): what the card needs (title, price, thumbnail, rating) plus
/// the category, which saving from a card needs. List and search pages ask the API for only these
/// fields (`select`); everything else comes from `/products/{id}` when details open. A separate type
/// so a list item can never pass for a `Product` whose details happen to be missing.
struct ProductSummary: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    /// Demo price in USD (D-11).
    let price: Decimal
    let thumbnailURL: URL?
    /// The API's aggregate rating (ProductSpecification § 6).
    let rating: Double?
    /// The API's category slug, e.g. `mens-shirts`.
    let category: String?
}

extension ProductSummary {
    /// What details show before `/products/{id}` returns: only the summary's facts, so every other
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

extension Product {
    /// The list fields of this product, e.g. to save it from details.
    var summary: ProductSummary {
        ProductSummary(id: id, title: title, price: price, thumbnailURL: thumbnailURL, rating: rating, category: category)
    }
}
