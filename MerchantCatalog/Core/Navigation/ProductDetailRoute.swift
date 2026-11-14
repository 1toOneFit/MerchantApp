/// What the details screen needs to open (D-83): the product's id and where it was opened from.
/// Details load the full product from `/products/{id}` and show a skeleton until it arrives; from
/// Saved, a failed request falls back to the saved snapshot, which details find in the store by id
/// (ProductSpecification § 4.3).
struct ProductDetailRoute: Hashable {
    let productID: Product.ID
    /// `.catalog`, `.search` or `.saved`.
    let source: ProductSource
}
