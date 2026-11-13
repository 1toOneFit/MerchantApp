import Testing
@testable import MerchantCatalog

/// Catalog copy fixed by the spec (ProductSpecification § 4.2).
struct CatalogCopyTests {
    /// Review finding 3: the exact planned text, with straight quotation marks.
    @Test func noResultsMessageMatchesTheSpec() {
        #expect(CatalogCopy.noResultsMessage(for: "zzz") == #"No products match "zzz""#)
    }
}
