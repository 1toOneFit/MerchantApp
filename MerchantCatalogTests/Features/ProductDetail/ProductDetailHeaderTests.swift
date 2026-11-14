import Foundation
import Testing
@testable import MerchantCatalog

/// The details header leads with what a merchant checks first: title, price, stock status,
/// category (with the brand), rating (ProductSpecification § 4.3 item 2, D-87).
struct ProductDetailHeaderTests {
    private static let enUS = Locale(identifier: "en_US")

    @Test func headerLeadsWithTitlePriceStockCategoryAndRating() {
        let product = makeProduct(
            id: 1,
            title: "Volume Mascara",
            price: Decimal(string: "1899.99"),
            brand: "Acme",
            category: "home-decoration",
            rating: 4.94,
            stock: 4
        )

        let header = ProductDetailHeader(product, locale: Self.enUS)

        #expect(header.title == "Volume Mascara")
        #expect(header.price == "$1,899.99")
        #expect(header.stock == StockLabel(stock: 4))
        #expect(header.stock?.text == "Low stock · 4 left")
        #expect(header.category == "Home Decoration")
        #expect(header.brand == "Acme")
        #expect(header.rating == "4.94")
    }

    /// The rating as the API gives it, up to 2 fraction digits (D-58).
    @Test(arguments: [(4.94, "4.94"), (4.5, "4.5"), (3.0, "3")])
    func ratingHasUpToTwoFractionDigits(rating: Double, text: String) {
        #expect(ProductDetailHeader(makeProduct(id: 1, rating: rating), locale: Self.enUS).rating == text)
    }

    /// 92 of 194 demo products have no brand (A10). A saved snapshot has no stock (D-89).
    @Test func headerWithoutBrandCategoryStockOrRating() {
        let header = ProductDetailHeader(makeProduct(id: 1, title: "Apple"), locale: Self.enUS)

        #expect(header.brand == nil)
        #expect(header.category == nil)
        #expect(header.stock == nil)
        #expect(header.rating == nil)
    }

    @Test func categoryNameReadsAsWords() {
        #expect(ProductDetailHeader.categoryName("mens-shirts") == "Mens Shirts")
    }
}
