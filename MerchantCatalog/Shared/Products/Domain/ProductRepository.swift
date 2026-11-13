/// Where products come from. View models depend only on this protocol; `AppContext` registers
/// `LiveProductRepository` under it. S3 adds search.
protocol ProductRepository: Sendable {
    /// One page of the catalog in `sort` order, starting at `skip`.
    ///
    /// - Throws: `AppError`, or `CancellationError` when the calling task is cancelled.
    func products(sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage
}
