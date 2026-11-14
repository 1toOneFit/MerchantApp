import Foundation
import Testing
@testable import MerchantCatalog

/// Snapshots are labeled as saved information (ProductSpecification § 4.4): "Price when saved:
/// $9.99 · Saved 3 Nov".
struct SavedProductFormatTests {
    private static let britishEnglish = Locale(identifier: "en_GB")

    @Test func priceWhenSaved() {
        #expect(SavedProductFormat.priceWhenSaved(Decimal(string: "9.99")!, locale: Self.britishEnglish) == "Price when saved: US$9.99")
        #expect(SavedProductFormat.priceWhenSaved(Decimal(string: "9.99")!, locale: Locale(identifier: "en_US")) == "Price when saved: $9.99")
    }

    @Test func savedDateUsesTheDayInTheGivenTimeZone() {
        let savedAt = date("2026-11-03T23:30:00Z")

        #expect(SavedProductFormat.savedDate(savedAt, locale: Self.britishEnglish, timeZone: .gmt) == "Saved 3 Nov")
        #expect(SavedProductFormat.savedDate(savedAt, locale: Self.britishEnglish, timeZone: TimeZone(identifier: "Europe/Kyiv")!) == "Saved 4 Nov")
    }
}
