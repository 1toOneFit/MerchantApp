import Foundation

/// The details header, in the order a merchant checks a product (ProductSpecification § 4.3 item 2,
/// D-87): title, price, stock status, category with the brand, rating.
struct ProductDetailHeader: Equatable {
    let title: String
    /// The demo price as USD in the locale's number format (D-11).
    let price: String
    /// "Low stock · 4 left"; `nil` when the stock is unknown, e.g. a saved snapshot (D-89).
    let stock: StockLabel?
    /// For display: "mens-shirts" reads "Mens Shirts".
    let category: String?
    let brand: String?
    /// The API's aggregate rating with up to 2 fraction digits, e.g. "4.94" (D-58).
    let rating: String?

    init(_ product: Product, locale: Locale = .current) {
        title = product.title
        price = product.price.formatted(.currency(code: "USD").locale(locale))
        stock = StockLabel(stock: product.stock)
        category = product.category.map(Self.categoryName)
        brand = product.brand
        rating = product.rating.map { $0.formatted(.number.precision(.fractionLength(0...2)).locale(locale)) }
    }

    /// The API's category slug as words, each starting with a capital letter.
    static func categoryName(_ slug: String) -> String {
        slug.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
