/// Catalog copy whose exact text the spec fixes (ProductSpecification § 4.2).
enum CatalogCopy {
    /// The no-results state's message (AC-S5).
    static func noResultsMessage(for query: String) -> String {
        "No products match \"\(query)\""
    }
}
