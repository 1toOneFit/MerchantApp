import Foundation
import Testing
@testable import MerchantCatalog

/// The details header (ProductSpecification § 4.3 item 2).
struct ProductDetailHeaderTests {
    @Test func headerShowsTitleBrandAndCategory() {
        let header = ProductDetailHeader(makeProduct(id: 1, title: "Volume Mascara", brand: "Acme", category: "home-decoration"))

        #expect(header == ProductDetailHeader(title: "Volume Mascara", brand: "Acme", category: "Home Decoration"))
    }

    /// 92 of 194 demo products have no brand (A10).
    @Test func headerWithoutBrandOrCategory() {
        let header = ProductDetailHeader(makeProduct(id: 1, title: "Apple"))

        #expect(header.brand == nil)
        #expect(header.category == nil)
    }
}
