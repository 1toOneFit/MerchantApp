import Foundation

/// What a catalog card shows: image, title, price and stock status, plus the rating in the
/// `treatment` arm of `product_card_density_v1` (ProductSpecification § 4.1, Experiments.md). The
/// stock row shows in both arms (D-86); category, brand and discount stay off the card (D-12).
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
    /// "Low stock · 4 left"; `nil` when the stock is unknown (D-84, D-86).
    let stock: StockLabel?

    init(product: ProductSummary, variant: ExperimentVariant, locale: Locale = .current) {
        let rating = variant == .treatment ? product.rating : nil
        self.init(
            id: product.id,
            title: product.title,
            price: product.price.formatted(.currency(code: "USD").locale(locale)),
            thumbnailURL: product.thumbnailURL,
            rating: rating,
            ratingText: rating.map { $0.formatted(.number.precision(.fractionLength(1)).locale(locale)) },
            stock: StockLabel(stock: product.stock)
        )
    }

    private init(id: Int, title: String, price: String, thumbnailURL: URL?, rating: Double?, ratingText: String?, stock: StockLabel?) {
        self.id = id
        self.title = title
        self.price = price
        self.thumbnailURL = thumbnailURL
        self.rating = rating
        self.ratingText = ratingText
        self.stock = stock
    }

    /// Low or out of stock: listed under Needs attention (D-85). Unknown stock never is.
    var needsAttention: Bool {
        stock?.status.needsAttention ?? false
    }

    /// Stand-in text for the redacted skeleton grid. No rating: the row's height is reserved in
    /// both arms anyway. A stock row, so the skeleton has the card's shape.
    static func placeholder(id: Int) -> ProductCardModel {
        ProductCardModel(id: id, title: "Product name placeholder", price: "$00.00", thumbnailURL: nil, rating: nil, ratingText: nil, stock: StockLabel(stock: 99))
    }
}
