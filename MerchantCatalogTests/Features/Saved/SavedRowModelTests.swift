import Foundation
import Testing
@testable import MerchantCatalog

/// A Saved row: thumbnail, title, price when saved, saved date; no rating (ProductSpecification
/// § 4.4).
struct SavedRowModelTests {
    @Test func rowShowsSavedInformation() {
        let item = SavedProduct(
            id: 7,
            title: "Desk Lamp",
            thumbnailURL: URL(string: "https://example.com/7.webp"),
            price: Decimal(string: "9.99")!,
            rating: 4.5,
            category: "home-decoration",
            savedAt: date("2026-11-13T10:00:00Z")
        )

        let row = SavedRowModel(item, locale: Locale(identifier: "en_US"), timeZone: .gmt)

        #expect(row.id == 7)
        #expect(row.title == "Desk Lamp")
        #expect(row.thumbnailURL == URL(string: "https://example.com/7.webp"))
        #expect(row.priceWhenSaved == "Price when saved: $9.99")
        #expect(row.savedDate == "Saved Nov 13")
    }
}
