import Foundation

/// What a catalog card shows: image, title and price, plus the rating in the `treatment` arm of
/// `product_card_density_v1` (ProductSpecification § 4.1, Experiments.md). Category, brand,
/// discount and availability stay off the card (D-12).
struct ProductCardModel: Identifiable, Equatable {
    let id: Int
    let title: String
    /// The demo price formatted as USD with the locale's number formatting.
    let price: String
    /// Loaded by `ProductImageView` only while the card is visible.
    let thumbnailURL: URL?
    /// Treatment only, and only when the product has one; VoiceOver reads it in the card's label.
    let rating: Double?
    /// `rating` with one fraction digit, e.g. "4.9" (D-71).
    let ratingText: String?

    init(product: Product, variant: ExperimentVariant, locale: Locale = .current) {
        let rating = variant == .treatment ? product.rating : nil
        self.init(
            id: product.id,
            title: product.title,
            price: product.price.formatted(.currency(code: "USD").locale(locale)),
            thumbnailURL: product.thumbnailURL,
            rating: rating,
            ratingText: rating.map { $0.formatted(.number.precision(.fractionLength(1)).locale(locale)) }
        )
    }

    private init(id: Int, title: String, price: String, thumbnailURL: URL?, rating: Double?, ratingText: String?) {
        self.id = id
        self.title = title
        self.price = price
        self.thumbnailURL = thumbnailURL
        self.rating = rating
        self.ratingText = ratingText
    }

    /// Stand-in text for the redacted skeleton grid. No rating: the row's height is reserved in
    /// both arms anyway.
    static func placeholder(id: Int) -> ProductCardModel {
        ProductCardModel(id: id, title: "Product name placeholder", price: "$00.00", thumbnailURL: nil, rating: nil, ratingText: nil)
    }
}
