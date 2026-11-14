/// Catalog copy whose exact text the spec fixes (ProductSpecification § 4.2, § 4.6).
enum CatalogCopy {
    /// The no-results state's message (AC-S5).
    static func noResultsMessage(for query: String) -> String {
        "No products match \"\(query)\""
    }

    /// How much of the list the Needs attention count has checked: only the products loaded so far
    /// (D-85), e.g. "Checked 120 of 194 products."
    static func attentionCoverage(_ coverage: AttentionCoverage) -> String {
        guard coverage.isComplete else {
            return "Checked \(coverage.loaded) of \(coverage.total) products."
        }
        return coverage.loaded == 1 ? "Checked 1 product." : "Checked all \(coverage.loaded) products."
    }

    /// The Needs attention footer's button: how many more products the next page checks, a full page
    /// or what is left of the list.
    static func checkMoreButton(_ coverage: AttentionCoverage, pageSize: Int) -> String {
        let next = max(1, min(pageSize, coverage.remaining))
        return next == 1 ? "Check 1 more product" : "Check \(next) more products"
    }
}
