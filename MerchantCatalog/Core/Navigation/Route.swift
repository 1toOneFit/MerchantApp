/// A destination pushed onto a tab's `NavigationStack`.
///
/// S4 replaces the payload with `ProductDetailRoute` (id, preloaded product, saved snapshot, source).
enum Route: Hashable {
    case productDetail(productID: Int)
}
