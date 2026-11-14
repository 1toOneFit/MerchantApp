import Foundation

/// One fact as the details screen shows it: a label, a value and an SF Symbol. Values are the API's
/// own: numbers with up to 2 fraction digits and no invented units (D-58), the discount as provided
/// with no computed price (D-11, ProductSpecification § 6). The price and rating are in the header
/// (`ProductDetailHeader`, D-87).
struct ProductFactRow: Equatable {
    let label: String
    let value: String
    let systemImage: String

    init(_ fact: ProductInsights.Fact, locale: Locale = .current) {
        let number = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2)).locale(locale)
        switch fact {
        case .availability(let availability):
            self.init("Availability", Self.title(of: availability), "shippingbox")
        case .stock(let stock):
            self.init("Stock", Self.units(stock), "number")
        case .minimumOrder(let quantity):
            self.init("Minimum order", Self.units(quantity), "cart")
        case .shipping(let shipping):
            self.init("Shipping", shipping, "truck.box")
        case .returnPolicy(let policy):
            self.init("Returns", policy, "arrow.uturn.backward")
        case .warranty(let warranty):
            self.init("Warranty", warranty, "checkmark.shield")
        case .discount(let percentage):
            let percent = (percentage / 100).formatted(.percent.precision(.fractionLength(0...2)).locale(locale))
            self.init("Discount", "\u{2212}\(percent)", "tag")
        case .description(let description):
            self.init("Description", description, "text.alignleft")
        case .tags(let tags):
            self.init("Tags", tags.joined(separator: ", "), "number.square")
        case .sku(let sku):
            self.init("SKU", sku, "barcode")
        case .brand(let brand):
            self.init("Brand", brand, "building.2")
        case .category(let category):
            self.init("Category", ProductDetailHeader.categoryName(category), "square.grid.2x2")
        case .weight(let weight):
            self.init("Weight", weight.formatted(number), "scalemass")
        case .dimensions(let dimensions):
            let values = [dimensions.width, dimensions.height, dimensions.depth].map { $0.formatted(number) }
            self.init("Dimensions (W × H × D)", values.joined(separator: " × "), "ruler")
        }
    }

    private init(_ label: String, _ value: String, _ systemImage: String) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }

    private static func title(of availability: StockStatus) -> String {
        switch availability {
        case .inStock: "In stock"
        case .lowStock: "Low stock"
        case .outOfStock: "Out of stock"
        }
    }

    private static func units(_ count: Int) -> String {
        count == 1 ? "1 unit" : "\(count) units"
    }
}
