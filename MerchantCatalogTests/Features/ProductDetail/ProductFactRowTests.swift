import Foundation
import Testing
@testable import MerchantCatalog

/// How each fact reads on the details screen (ProductSpecification § 4.3, § 6): values as the API
/// gives them, without invented units (D-58).
struct ProductFactRowTests {
    private static let enUS = Locale(identifier: "en_US")

    @Test(arguments: [
        (ProductInsights.Fact.availability(.lowStock), "Availability", "Low stock"),
        (.availability(.inStock), "Availability", "In stock"),
        (.availability(.outOfStock), "Availability", "Out of stock"),
        (.stock(5), "Stock", "5 units"),
        (.stock(0), "Stock", "0 units"),
        (.minimumOrder(48), "Minimum order", "48 units"),
        (.minimumOrder(1), "Minimum order", "1 unit"),
        (.shipping("Ships in 1 month"), "Shipping", "Ships in 1 month"),
        (.returnPolicy("No return policy"), "Returns", "No return policy"),
        (.warranty("1 month warranty"), "Warranty", "1 month warranty"),
        (.discount(7.17), "Discount", "−7.17%"),
        (.discount(7), "Discount", "−7%"),
        (.discount(0.04), "Discount", "−0.04%"),
        (.description("A lengthening mascara."), "Description", "A lengthening mascara."),
        (.tags(["beauty", "mascara"]), "Tags", "beauty, mascara"),
        (.sku("BEA-ACM-001"), "SKU", "BEA-ACM-001"),
        (.brand("Acme"), "Brand", "Acme"),
        (.category("mens-shirts"), "Category", "Mens Shirts"),
        (.weight(4), "Weight", "4"),
        (.dimensions(ProductDimensions(width: 15.14, height: 13.08, depth: 22.99)), "Dimensions (W × H × D)", "15.14 × 13.08 × 22.99"),
    ])
    func formatsFact(fact: ProductInsights.Fact, label: String, value: String) {
        let row = ProductFactRow(fact, locale: Self.enUS)

        #expect(row.label == label)
        #expect(row.value == value)
        #expect(!row.systemImage.isEmpty)
    }
}
