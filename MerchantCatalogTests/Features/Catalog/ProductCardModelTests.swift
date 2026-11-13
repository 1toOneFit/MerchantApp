import Foundation
import Testing
@testable import MerchantCatalog

/// What a catalog card shows in S2: image, title, price (ProductSpecification § 4.1).
struct ProductCardModelTests {
    private static let enUS = Locale(identifier: "en_US")

    @Test func exposesThumbnailURL() {
        let card = ProductCardModel(product: product(7), locale: Self.enUS)

        #expect(card.id == 7)
        #expect(card.title == "Product 7")
        #expect(card.thumbnailURL == URL(string: "https://cdn.dummyjson.com/products/7/thumbnail.webp"))
    }

    @Test(arguments: [("9.99", "$9.99"), ("1899.99", "$1,899.99"), ("0.5", "$0.50")])
    func formatsPriceAsUSD(price: String, expected: String) throws {
        let product = Product(
            id: 1,
            title: "Item",
            price: try #require(Decimal(string: price)),
            brand: nil,
            availability: nil,
            thumbnailURL: nil,
            imageURLs: []
        )

        #expect(ProductCardModel(product: product, locale: Self.enUS).price == expected)
    }

    @Test func placeholderHasNoImage() {
        #expect(ProductCardModel.placeholder(id: 3).thumbnailURL == nil)
        #expect(ProductCardModel.placeholder(id: 3).id == 3)
    }
}
