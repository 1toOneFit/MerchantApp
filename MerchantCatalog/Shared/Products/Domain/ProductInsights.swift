import Foundation

/// The facts the details screen shows below its header, grouped per section (ProductSpecification
/// § 4.3). Title, price, stock status, category and rating lead the header instead (D-87).
///
/// Insight rule: only facts present in the data, never an invented score, recommendation or
/// computed price (D-11). A missing value leaves its fact out, and an empty group means the
/// section is omitted, never shown empty (AC-D2).
struct ProductInsights: Equatable, Sendable {
    /// One fact about a product, as the API gives it (D-58).
    enum Fact: Hashable, Sendable {
        /// The status from the stock by the one policy (D-84).
        case availability(StockStatus)
        case stock(Int)
        case minimumOrder(Int)
        case shipping(String)
        case returnPolicy(String)
        case warranty(String)
        /// Only when greater than 0.
        case discount(Double)
        case description(String)
        case tags([String])
        case sku(String)
        case brand(String)
        case category(String)
        case weight(Double)
        case dimensions(ProductDimensions)
    }

    /// Minimum order, shipping, return policy, warranty.
    let atAGlance: [Fact]
    /// The discount when there is one; the price is in the header (D-87).
    let pricing: [Fact]
    /// Description and tags.
    let overview: [Fact]
    /// SKU, brand, category, weight, dimensions, warranty.
    let productInformation: [Fact]
    /// Availability, stock, shipping, minimum order, return policy.
    let shippingAndAvailability: [Fact]
    /// "Recent reviews".
    let reviews: [ProductReview]

    init(_ product: Product) {
        atAGlance = [
            product.minimumOrderQuantity.map(Fact.minimumOrder),
            product.shipping.map(Fact.shipping),
            product.returnPolicy.map(Fact.returnPolicy),
            product.warranty.map(Fact.warranty),
        ].compactMap(\.self)
        pricing = [
            product.discountPercentage.flatMap { $0 > 0 ? Fact.discount($0) : nil },
        ].compactMap(\.self)
        overview = [
            product.productDescription.map(Fact.description),
            product.tags.isEmpty ? nil : Fact.tags(product.tags),
        ].compactMap(\.self)
        productInformation = [
            product.sku.map(Fact.sku),
            product.brand.map(Fact.brand),
            product.category.map(Fact.category),
            product.weight.map(Fact.weight),
            product.dimensions.map(Fact.dimensions),
            product.warranty.map(Fact.warranty),
        ].compactMap(\.self)
        shippingAndAvailability = [
            product.stockStatus.map(Fact.availability),
            product.stock.map(Fact.stock),
            product.shipping.map(Fact.shipping),
            product.minimumOrderQuantity.map(Fact.minimumOrder),
            product.returnPolicy.map(Fact.returnPolicy),
        ].compactMap(\.self)
        reviews = product.reviews
    }
}
