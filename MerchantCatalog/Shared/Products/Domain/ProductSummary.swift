import Foundation

/// A product as a list shows it (D-81): what the card needs (title, price, thumbnail, rating, stock)
/// plus the category, which saving from a card needs. List and search pages ask the API for only
/// these fields (`select`); everything else comes from `/products/{id}` when details open. A separate
/// type so a list item can never pass for a `Product` whose details happen to be missing.
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
    /// Units in stock, for the card's status and Needs attention (D-84, D-85); `nil` when unknown.
    /// A saved snapshot keeps none (D-89).
    let stock: Int?

    init(id: Int, title: String, price: Decimal, thumbnailURL: URL?, rating: Double?, category: String?, stock: Int? = nil) {
        self.id = id
        self.title = title
        self.price = price
        self.thumbnailURL = thumbnailURL
        self.rating = rating
        self.category = category
        self.stock = stock
    }

    /// From `stock` by the one policy (D-84).
    var stockStatus: StockStatus? {
        StockStatus(stock: stock)
    }
}

extension ProductSummary {
    /// What details show for a saved snapshot when `/products/{id}` fails: only the summary's facts,
    /// so every other section is omitted (AC-D2). No gallery: the gallery never shows the thumbnail
    /// (D-67). No stock: a snapshot's would be the stock when saved (D-89).
    var displayProduct: Product {
        Product(
            id: id,
            title: title,
            price: price,
            brand: nil,
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
        ProductSummary(id: id, title: title, price: price, thumbnailURL: thumbnailURL, rating: rating, category: category, stock: stock)
    }
}
