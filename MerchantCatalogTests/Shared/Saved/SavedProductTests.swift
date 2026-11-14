import Foundation
import Testing
@testable import MerchantCatalog

/// A saved product is a snapshot of the fields ProductSpecification § 4.4 lists, plus when it was
/// saved.
struct SavedProductTests {
    private static let savedAt = date("2026-11-13T10:00:00Z")

    private static let summary = ProductSummary(
        id: 7,
        title: "Desk Lamp",
        price: Decimal(string: "24.99")!,
        thumbnailURL: URL(string: "https://example.com/7.webp"),
        rating: 4.5,
        category: "home-decoration"
    )

    /// The snapshot is the list item's summary plus when it was saved (D-81).
    @Test func snapshotKeepsTheSummaryFields() {
        let saved = SavedProduct(Self.summary, savedAt: Self.savedAt)

        #expect(saved == SavedProduct(
            id: 7,
            title: "Desk Lamp",
            thumbnailURL: URL(string: "https://example.com/7.webp"),
            price: Decimal(string: "24.99")!,
            rating: 4.5,
            category: "home-decoration",
            savedAt: Self.savedAt
        ))
        #expect(saved.summary == Self.summary)
    }

    /// Details show a snapshot like a summary: only its facts, no gallery, brand or availability (D-67).
    @Test func displayProductIsTheSummarysDisplayProduct() {
        let saved = SavedProduct(Self.summary, savedAt: Self.savedAt)

        #expect(saved.displayProduct == Self.summary.displayProduct)
    }
}
