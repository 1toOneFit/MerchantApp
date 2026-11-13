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
}
