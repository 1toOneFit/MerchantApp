import Foundation
import Testing
@testable import MerchantCatalog

/// The details screen's facts (ProductSpecification § 4.3): only facts present in the data, grouped
/// per section; an empty group means the section is omitted (AC-D2).
struct ProductInsightsTests {
    private static let dimensions = ProductDimensions(width: 15.14, height: 13.08, depth: 22.99)
    private static let review = ProductReview(rating: 3, comment: "Fine.", reviewerName: "Reviewer One", date: nil)

    private static let full = makeProduct(
        id: 1,
        price: 9.99,
        brand: "Acme",
        availability: .lowStock,
        productDescription: "A lengthening mascara.",
        category: "beauty",
        tags: ["beauty", "mascara"],
        rating: 4.94,
        discountPercentage: 7.17,
        stock: 5,
        sku: "BEA-ACM-001",
        weight: 4,
        dimensions: dimensions,
        warranty: "1 month warranty",
        shipping: "Ships in 1 month",
        returnPolicy: "No return policy",
        minimumOrderQuantity: 48,
        reviews: [review]
    )

    @Test func fullProductHasEveryFact() {
        let insights = ProductInsights(Self.full)

        #expect(insights.atAGlance == [
            .rating(4.94),
            .availability(.lowStock, units: 5),
            .minimumOrder(48),
            .shipping("Ships in 1 month"),
            .returnPolicy("No return policy"),
            .warranty("1 month warranty"),
        ])
        #expect(insights.pricing == [.price(9.99), .discount(7.17)])
        #expect(insights.overview == [.description("A lengthening mascara."), .tags(["beauty", "mascara"])])
        #expect(insights.productInformation == [
            .sku("BEA-ACM-001"),
            .brand("Acme"),
            .category("beauty"),
            .weight(4),
            .dimensions(Self.dimensions),
            .warranty("1 month warranty"),
        ])
        #expect(insights.shippingAndAvailability == [
            .availability(.lowStock, units: nil),
            .stock(5),
            .shipping("Ships in 1 month"),
            .minimumOrder(48),
            .returnPolicy("No return policy"),
        ])
        #expect(insights.reviews == [Self.review])
    }

    /// Review Focus 1: a product with almost no data has no empty section or row.
    @Test func sparseProductKeepsOnlyCoreFacts() {
        let insights = ProductInsights(makeProduct(id: 2, price: 9.99, rating: 4.5, discountPercentage: 0))

        #expect(insights.atAGlance == [.rating(4.5)])
        #expect(insights.pricing == [.price(9.99)])
        #expect(insights.overview.isEmpty)
        #expect(insights.productInformation.isEmpty)
        #expect(insights.shippingAndAvailability.isEmpty)
        #expect(insights.reviews.isEmpty)
    }

    @Test func noBrandMeansNoBrandRow() {
        let insights = ProductInsights(makeProduct(id: 3, sku: "SKU-1"))

        #expect(insights.productInformation == [.sku("SKU-1")])
    }

    @Test(arguments: [Double?.some(0), nil])
    func zeroOrMissingDiscountIsOmitted(discount: Double?) {
        let insights = ProductInsights(makeProduct(id: 4, price: 5, discountPercentage: discount))

        #expect(insights.pricing == [.price(5)])
    }

    @Test func availabilityCarriesStock() {
        let insights = ProductInsights(makeProduct(id: 5, availability: .outOfStock, stock: 0))

        #expect(insights.atAGlance == [.availability(.outOfStock, units: 0)])
        #expect(insights.shippingAndAvailability == [.availability(.outOfStock, units: nil), .stock(0)])
    }

    @Test func unknownAvailabilityKeepsStock() {
        let insights = ProductInsights(makeProduct(id: 6, stock: 7))

        #expect(insights.atAGlance.isEmpty)
        #expect(insights.shippingAndAvailability == [.stock(7)])
    }
}
