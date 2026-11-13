import SwiftUI

/// The catalog grid's columns (ProductSpecification § 2, § 4.5): two flexible columns, one at the
/// accessibility text sizes (AX1–AX5), where two columns would leave each title a few words per line
/// (D-75). The grid and its skeleton both use it, so the skeleton matches the grid.
enum CatalogLayout {
    static let rowSpacing: CGFloat = 20

    static func columnCount(for size: DynamicTypeSize) -> Int {
        size.isAccessibilitySize ? 1 : 2
    }

    static func columns(for size: DynamicTypeSize) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columnCount(for: size))
    }
}
