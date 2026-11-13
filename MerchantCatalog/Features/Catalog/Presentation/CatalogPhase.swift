/// What the catalog screen shows (ProductSpecification § 4.1 states; Architecture § 8).
enum CatalogPhase: Equatable {
    /// No content yet, first page in flight: the skeleton grid.
    case initialLoading
    /// At least one product. Pull-to-refresh uses the system refresh control; a refresh failure
    /// shows `refreshError` as a banner over the content.
    case content(footer: CatalogFooter, refreshError: AppError?)
    /// A successful first page with no products: message and Reload.
    case empty
    /// The first page failed: full-screen, reason-specific message and Retry.
    case failed(AppError)
}

/// The row under the grid.
enum CatalogFooter: Equatable {
    /// More pages exist; the next loads when the user scrolls near the end.
    case idle
    /// Page ≥ 2 in flight: spinner.
    case loading
    /// Page ≥ 2 failed: message and Retry; content stays.
    case failed(AppError)
    /// Everything is loaded: "You've reached the end".
    case end
}
