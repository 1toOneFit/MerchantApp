import Foundation
import Testing
@testable import MerchantCatalog

/// VoiceOver reads each card as one element, "Title, price[, rating], saved/not saved", with a
/// custom action to save or unsave (ProductSpecification § 4.5; S5 review finding 3).
struct ProductCardAccessibilityTests {
    private static let english = Locale(identifier: "en_US")

    @Test func labelWithoutRating() {
        #expect(ProductCardAccessibility.label(title: "Volume Mascara", price: "$9.99", rating: nil, isSaved: false, locale: Self.english)
            == "Volume Mascara, $9.99, not saved")
    }

    @Test func labelWithRatingWhenSaved() {
        #expect(ProductCardAccessibility.label(title: "Volume Mascara", price: "$9.99", rating: 4.56, isSaved: true, locale: Self.english)
            == "Volume Mascara, $9.99, rated 4.6 of 5, saved")
    }

    @Test func saveActionNameSaysWhatItDoes() {
        #expect(ProductCardAccessibility.saveActionName(isSaved: false) == "Save")
        #expect(ProductCardAccessibility.saveActionName(isSaved: true) == "Remove from Saved")
    }
}
