import Testing
@testable import MerchantCatalog

/// Catalog copy fixed by the spec (ProductSpecification § 4.2).
struct CatalogCopyTests {
    /// Review finding 3: the exact planned text, with straight quotation marks.
    @Test func noResultsMessageMatchesTheSpec() {
        #expect(CatalogCopy.noResultsMessage(for: "zzz") == #"No products match "zzz""#)
    }

    /// Needs attention says how much of the list its count has checked: only the products loaded
    /// so far (D-85; plainer wording at the developer's request).
    @Test(arguments: [
        (AttentionCoverage(loaded: 120, total: 194, remaining: 74, isComplete: false), "Checked 120 of 194 products."),
        (AttentionCoverage(loaded: 194, total: 194, remaining: 0, isComplete: true), "Checked all 194 products."),
        (AttentionCoverage(loaded: 1, total: 1, remaining: 0, isComplete: true), "Checked 1 product."),
    ])
    func attentionCoverage(coverage: AttentionCoverage, expected: String) {
        #expect(CatalogCopy.attentionCoverage(coverage) == expected)
    }

    /// The button says how many more products it will check: a page, or what is left of the list.
    @Test(arguments: [(174, "Check 20 more products"), (14, "Check 14 more products"), (1, "Check 1 more product")])
    func checkMoreButton(remaining: Int, expected: String) {
        let coverage = AttentionCoverage(loaded: 194 - remaining, total: 194, remaining: remaining, isComplete: false)

        #expect(CatalogCopy.checkMoreButton(coverage, pageSize: 20) == expected)
    }
}
