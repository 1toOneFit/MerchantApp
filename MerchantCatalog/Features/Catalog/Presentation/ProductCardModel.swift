import Foundation

/// What a catalog card shows: image, title and price (ProductSpecification § 4.1). Category,
/// brand, discount and availability stay off the card (D-12); S6 adds the rating in treatment.
struct ProductCardModel: Identifiable, Equatable {
    let id: Int
    let title: String
    /// The demo price formatted as USD with the locale's number formatting.
    let price: String
    /// Loaded by `ProductImageView` only while the card is visible.
    let thumbnailURL: URL?

    init(product: Product, locale: Locale = .current) {
        self.init(
            id: product.id,
            title: product.title,
            price: product.price.formatted(.currency(code: "USD").locale(locale)),
            thumbnailURL: product.thumbnailURL
        )
    }

    private init(id: Int, title: String, price: String, thumbnailURL: URL?) {
        self.id = id
        self.title = title
        self.price = price
        self.thumbnailURL = thumbnailURL
    }

    /// Stand-in text for the redacted skeleton grid.
    static func placeholder(id: Int) -> ProductCardModel {
        ProductCardModel(id: id, title: "Product name placeholder", price: "$00.00", thumbnailURL: nil)
    }
}
