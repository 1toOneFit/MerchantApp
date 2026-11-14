import SwiftUI
import Testing
@testable import MerchantCatalog

/// The catalog grid keeps two columns up to the largest standard text size and switches to one
/// column at every accessibility size (ProductSpecification § 4.5, D-75).
struct CatalogLayoutTests {
    @Test(arguments: DynamicTypeSize.allCases)
    func columnCountFollowsAccessibilitySizes(size: DynamicTypeSize) {
        #expect(CatalogLayout.columnCount(for: size) == (size.isAccessibilitySize ? 1 : 2))
    }

    /// Pins the boundary without relying on `isAccessibilitySize`, which the rule itself uses.
    @Test func boundaryIsTheFirstAccessibilitySize() {
        #expect(CatalogLayout.columnCount(for: .xSmall) == 2)
        #expect(CatalogLayout.columnCount(for: .large) == 2)
        #expect(CatalogLayout.columnCount(for: .xxxLarge) == 2)
        #expect(CatalogLayout.columnCount(for: .accessibility1) == 1)
        #expect(CatalogLayout.columnCount(for: .accessibility5) == 1)
    }

    /// The grid and the skeleton both lay out `columns(for:)`, so the skeleton matches the grid.
    @Test func columnsMatchTheCount() {
        #expect(CatalogLayout.columns(for: .large).count == 2)
        #expect(CatalogLayout.columns(for: .accessibility3).count == 1)
    }
}
