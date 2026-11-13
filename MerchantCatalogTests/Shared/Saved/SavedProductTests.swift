import Foundation
import Testing
@testable import MerchantCatalog

/// A saved product is a snapshot of the fields ProductSpecification § 4.4 lists, plus when it was
/// saved.
struct SavedProductTests {
    private static let savedAt = date("2026-11-13T10:00:00Z")

    @Test func snapshotKeepsTheSpecFields() {
        let source = makeProduct(
            id: 7,
            title: "Desk Lamp",
            price: Decimal(string: "24.99"),
            brand: "Acme",
            availability: .lowStock,
            imageURLs: [URL(string: "https://cdn.dummyjson.com/products/7/1.webp")!],
            category: "home-decoration",
            rating: 4.5,
            discountPercentage: 3
        )

        let saved = SavedProduct(source, savedAt: Self.savedAt)

        #expect(saved == SavedProduct(
            id: 7,
            title: "Desk Lamp",
            thumbnailURL: URL(string: "https://cdn.dummyjson.com/products/7/thumbnail.webp"),
            price: Decimal(string: "24.99")!,
            rating: 4.5,
            category: "home-decoration",
            savedAt: Self.savedAt
        ))
    }

    /// Details show a snapshot as a product with only the snapshot's facts (D-67): no gallery, brand
    /// or availability.
    @Test func displayProductCarriesOnlySnapshotFields() {
        let saved = SavedProduct(
            id: 7,
            title: "Desk Lamp",
            thumbnailURL: URL(string: "https://example.com/7.webp"),
            price: Decimal(string: "24.99")!,
            rating: 4.5,
            category: "home-decoration",
            savedAt: Self.savedAt
        )

        #expect(saved.displayProduct == makeProduct(
            id: 7,
            title: "Desk Lamp",
            price: Decimal(string: "24.99"),
            thumbnailURL: URL(string: "https://example.com/7.webp"),
            category: "home-decoration",
            rating: 4.5
        ))
    }
}
