/// What the details screen needs to open: the product as the list loaded it (the list endpoint
/// returns full products, Networking.md A7) and where it was opened from. S5 extends it for
/// products opened from Saved (snapshot, then `/products/{id}`) (D-57).
struct ProductDetailRoute: Hashable {
    let product: Product
    let source: ProductSource
}
