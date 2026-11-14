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

    /// A saved product is the very summary that goes from a list to details, plus when it was saved
    /// (D-82): opening it from Saved hands details the same piece of data.
    @Test func snapshotIsTheSummaryPlusTheSaveDate() {
        let saved = SavedProduct(summary: Self.summary, savedAt: Self.savedAt)

        #expect(saved.summary == Self.summary)
        #expect(saved.id == 7)
        #expect(saved.savedAt == Self.savedAt)
    }

    /// Review Focus 4 (D-89): a snapshot keeps no stock count. It would be the stock when saved,
    /// shown offline as if current; the file has no field for it either.
    @Test func snapshotKeepsNoStock() {
        let listed = ProductSummary(id: 7, title: "Desk Lamp", price: 24.99, thumbnailURL: nil, rating: 4.5, category: nil, stock: 4)

        let saved = SavedProduct(summary: listed, savedAt: Self.savedAt)

        #expect(saved.summary.stock == nil)
        #expect(saved.summary.title == "Desk Lamp")
        #expect(saved.summary.price == 24.99)
    }

    /// Details show a snapshot like a summary: only its facts, no gallery, brand or availability (D-67).
    @Test func displayProductIsTheSummarysDisplayProduct() {
        let saved = SavedProduct(summary: Self.summary, savedAt: Self.savedAt)

        #expect(saved.displayProduct == Self.summary.displayProduct)
    }
}
