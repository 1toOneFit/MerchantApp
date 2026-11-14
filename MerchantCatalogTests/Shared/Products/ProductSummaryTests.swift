import Foundation
import Testing
@testable import MerchantCatalog

/// What a list item carries (D-81): the card's fields plus the category, which saving from a card
/// needs. A full product reduces to the same summary; before the details request returns, details
/// show the summary as a product with only these facts.
struct ProductSummaryTests {
    @Test func productReducesToItsSummary() {
        let product = makeProduct(
            id: 7,
            title: "Desk Lamp",
            price: Decimal(string: "24.99"),
            brand: "Acme",
            imageURLs: [URL(string: "https://cdn.dummyjson.com/products/7/1.webp")!],
            category: "home-decoration",
            rating: 4.5,
            discountPercentage: 3,
            stock: 4
        )

        #expect(product.summary == ProductSummary(
            id: 7,
            title: "Desk Lamp",
            price: Decimal(string: "24.99")!,
            thumbnailURL: URL(string: "https://cdn.dummyjson.com/products/7/thumbnail.webp"),
            rating: 4.5,
            category: "home-decoration",
            stock: 4
        ))
    }

    /// No gallery, brand or stock: only what the summary knows (D-67, D-81). It shows a saved
    /// snapshot, whose stock would be the stock when saved (D-89).
    @Test func displayProductCarriesOnlyTheSummaryFields() {
        let summary = ProductSummary(
            id: 7,
            title: "Desk Lamp",
            price: Decimal(string: "24.99")!,
            thumbnailURL: URL(string: "https://example.com/7.webp"),
            rating: 4.5,
            category: "home-decoration",
            stock: 3
        )

        #expect(summary.displayProduct == makeProduct(
            id: 7,
            title: "Desk Lamp",
            price: Decimal(string: "24.99"),
            thumbnailURL: URL(string: "https://example.com/7.webp"),
            category: "home-decoration",
            rating: 4.5
        ))
    }
}
