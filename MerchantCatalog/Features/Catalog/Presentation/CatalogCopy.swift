/// Catalog copy whose exact text the spec fixes (ProductSpecification § 4.2, § 4.6).
enum CatalogCopy {
    /// The no-results state's message (AC-S5).
    static func noResultsMessage(for query: String) -> String {
        "No products match \"\(query)\""
    }

    /// What the Needs attention count is based on: only the products loaded so far (D-85).
    static func attentionCoverage(_ coverage: AttentionCoverage) -> String {
        guard coverage.isComplete else {
            return "Based on \(coverage.loaded) of \(coverage.total) products loaded so far."
        }
        return coverage.loaded == 1 ? "Based on the 1 product." : "Based on all \(coverage.loaded) products."
    }
}
