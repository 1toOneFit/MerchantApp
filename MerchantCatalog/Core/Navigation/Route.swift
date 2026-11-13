/// A destination pushed onto a tab's navigation stack.
enum Route: Hashable {
    case productDetail(ProductDetailRoute)

    /// For the `navigation` log: ids and enum values only, never a product title (Architecture § 10).
    var logDescription: String {
        switch self {
        case .productDetail(let route):
            "productDetail(id: \(route.product.id), source: \(route.source.rawValue))"
        }
    }
}
