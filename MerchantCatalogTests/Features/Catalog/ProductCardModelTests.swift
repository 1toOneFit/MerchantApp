import Foundation
import Testing
@testable import MerchantCatalog

/// What a catalog card shows: image, title, price, and the rating only in `treatment`
/// (ProductSpecification § 4.1, Experiments.md, D-71).
struct ProductCardModelTests {
    private static let enUS = Locale(identifier: "en_US")

    @Test func exposesThumbnailURL() {
        let card = ProductCardModel(product: summary(7), variant: .control, locale: Self.enUS)

        #expect(card.id == 7)
        #expect(card.title == "Product 7")
        #expect(card.thumbnailURL == URL(string: "https://cdn.dummyjson.com/products/7/thumbnail.webp"))
    }

    @Test(arguments: [("9.99", "$9.99"), ("1899.99", "$1,899.99"), ("0.5", "$0.50")])
    func formatsPriceAsUSD(price: String, expected: String) {
        guard let value = Decimal(string: price) else {
            Issue.record("not a decimal: \(price)")
            return
        }
        let product = makeSummary(id: 1, title: "Item", price: value, thumbnailURL: .some(nil))

        #expect(ProductCardModel(product: product, variant: .control, locale: Self.enUS).price == expected)
    }

    @Test func treatmentCardShowsTheRating() {
        let card = ProductCardModel(product: makeSummary(id: 1, rating: 4.94), variant: .treatment, locale: Self.enUS)

        #expect(card.rating == 4.94)
        #expect(card.ratingText == "4.9")
    }

    /// One fraction digit, rounded: 4.96 shows as "5.0" (D-71).
    @Test(arguments: [(2.51, "2.5"), (4.96, "5.0"), (3.0, "3.0")])
    func ratingHasOneFractionDigit(rating: Double, text: String) {
        let card = ProductCardModel(product: makeSummary(id: 1, rating: rating), variant: .treatment, locale: Self.enUS)

        #expect(card.ratingText == text)
    }

    @Test func controlCardHasNoRating() {
        let card = ProductCardModel(product: makeSummary(id: 1, rating: 4.94), variant: .control, locale: Self.enUS)

        #expect(card.rating == nil)
        #expect(card.ratingText == nil)
    }

    @Test func treatmentWithoutRatingShowsNone() {
        let card = ProductCardModel(product: makeSummary(id: 1, rating: nil), variant: .treatment, locale: Self.enUS)

        #expect(card.rating == nil)
        #expect(card.ratingText == nil)
    }

    /// D-86: the stock row shows in both arms; only the rating differs.
    @Test(arguments: [ExperimentVariant.control, .treatment])
    func cardCarriesStockLabel(variant: ExperimentVariant) {
        let card = ProductCardModel(product: makeSummary(id: 1, stock: 4), variant: variant, locale: Self.enUS)

        #expect(card.stock == StockLabel(stock: 4))
        #expect(card.stock?.text == "Low stock · 4 left")
    }

    /// Review Focus 3: unknown stock shows no status.
    @Test func cardWithoutStockHasNoLabel() {
        #expect(ProductCardModel(product: makeSummary(id: 1, stock: nil), variant: .control, locale: Self.enUS).stock == nil)
    }

    @Test func placeholderHasNoImage() {
        #expect(ProductCardModel.placeholder(id: 3).thumbnailURL == nil)
        #expect(ProductCardModel.placeholder(id: 3).id == 3)
    }
}
