/// The orders the catalog can be shown in. Sorting always happens on the server, over the whole
/// result set (Networking.md A2, A3); the app never sorts locally.
enum ProductSort: CaseIterable, Sendable {
    /// The API's default order (by id); sends no `sortBy`.
    case defaultOrder
    case priceAscending
    case priceDescending
    case ratingDescending
}
