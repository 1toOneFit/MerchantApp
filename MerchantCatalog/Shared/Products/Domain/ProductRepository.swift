/// Where products come from. View models depend only on this protocol; `AppContext` registers
/// `LiveProductRepository` under it.
protocol ProductRepository: Sendable {
    /// One page of the catalog in `sort` order, starting at `skip`.
    ///
    /// - Throws: `AppError`, or `CancellationError` when the calling task is cancelled.
    func products(sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage

    /// One page of the products matching `query` in `sort` order, starting at `skip`. The server
    /// searches, sorts and paginates (Networking.md A3); an empty page with `total == 0` means no
    /// matches (A5).
    ///
    /// - Throws: `AppError`, or `CancellationError` when the calling task is cancelled.
    func search(query: String, sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage

    /// One product with all its details, fresh from the server. Details fetch it whenever they open
    /// (ProductSpecification § 4.3, D-81).
    ///
    /// - Throws: `AppError` (`.notFound` for an unknown id, Networking.md A6), or
    ///   `CancellationError` when the calling task is cancelled.
    func product(id: Product.ID) async throws -> Product
}
