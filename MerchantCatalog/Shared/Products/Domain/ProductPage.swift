/// One page of a product list, with the server's pagination fields (Networking.md A1).
struct ProductPage: Equatable, Sendable {
    let products: [Product]
    /// Products in the whole result set.
    let total: Int
    /// Offset of the first product in this page.
    let skip: Int
    /// The page size the server reports.
    let limit: Int
}
