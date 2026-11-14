import Testing
@testable import MerchantCatalog

/// Catalog copy fixed by the spec (ProductSpecification § 4.2).
struct CatalogCopyTests {
    /// Review finding 3: the exact planned text, with straight quotation marks.
    @Test func noResultsMessageMatchesTheSpec() {
        #expect(CatalogCopy.noResultsMessage(for: "zzz") == #"No products match "zzz""#)
    }

    /// Needs attention says what its count is based on: only the products loaded so far (D-85).
    @Test(arguments: [
        (AttentionCoverage(loaded: 20, total: 194, isComplete: false), "Based on 20 of 194 products loaded so far."),
        (AttentionCoverage(loaded: 194, total: 194, isComplete: true), "Based on all 194 products."),
        (AttentionCoverage(loaded: 1, total: 1, isComplete: true), "Based on the 1 product."),
    ])
    func attentionCoverage(coverage: AttentionCoverage, expected: String) {
        #expect(CatalogCopy.attentionCoverage(coverage) == expected)
    }
}
