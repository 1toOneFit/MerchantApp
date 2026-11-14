/// What the details screen needs to open (D-62):
/// - `list`: the list item the browse grid or search results loaded (a summary, D-81), and which list
///   it came from;
/// - `saved`: the saved snapshot.
/// Either shows first while `/products/{id}` loads the full product (ProductSpecification § 4.3).
enum ProductDetailRoute: Hashable {
    /// `source`: `.catalog` or `.search`.
    case list(ProductSummary, source: ProductSource)
    case saved(SavedProduct)

    /// The piece of data both routes hand details (D-82): the list item, or the summary that was
    /// saved.
    var summary: ProductSummary {
        switch self {
        case .list(let summary, _): summary
        case .saved(let snapshot): snapshot.summary
        }
    }

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
