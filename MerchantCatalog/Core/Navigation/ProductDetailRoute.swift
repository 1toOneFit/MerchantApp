/// What the details screen needs to open (D-62):
/// - `list`: the product as the browse grid or search results loaded it (the list endpoint returns
///   full products, Networking.md A7), and which list it came from;
/// - `saved`: the saved snapshot, shown first while `/products/{id}` refreshes it
///   (ProductSpecification § 4.3).
enum ProductDetailRoute: Hashable {
    /// `source`: `.catalog` or `.search`.
    case list(Product, source: ProductSource)
    case saved(SavedProduct)

    var productID: Product.ID {
        switch self {
        case .list(let product, _): product.id
        case .saved(let snapshot): snapshot.id
        }
    }

    var source: ProductSource {
        switch self {
        case .list(_, let source): source
        case .saved: .saved
        }
    }
}
