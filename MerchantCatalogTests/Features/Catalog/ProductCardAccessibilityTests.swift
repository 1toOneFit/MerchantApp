import Foundation
import Testing
@testable import MerchantCatalog

/// VoiceOver reads each card as one element, "Title, price[, stock][, rating], saved/not saved",
/// with a custom action to save or unsave (ProductSpecification § 4.5; S5 review finding 3, S7,
/// D-86).
struct ProductCardAccessibilityTests {
    private static let english = Locale(identifier: "en_US")

    /// Every combination: the rating only when the card shows one (treatment), the saved state always.
    @Test(arguments: [
        (nil, false, "Volume Mascara, $9.99, not saved"),
        (nil, true, "Volume Mascara, $9.99, saved"),
        (4.56, false, "Volume Mascara, $9.99, rated 4.6 of 5, not saved"),
        (4.56, true, "Volume Mascara, $9.99, rated 4.6 of 5, saved"),
    ] as [(Double?, Bool, String)])
    func labelCombinesTitlePriceRatingAndSavedState(rating: Double?, isSaved: Bool, expected: String) {
        #expect(ProductCardAccessibility.label(title: "Volume Mascara", price: "$9.99", stock: nil, rating: rating, isSaved: isSaved, locale: Self.english)
            == expected)
    }

    /// The stock status follows the price, before the rating (D-86).
    @Test(arguments: [
        (nil, "Volume Mascara, $9.99, Low stock, 4 left, not saved"),
        (4.56, "Volume Mascara, $9.99, Low stock, 4 left, rated 4.6 of 5, not saved"),
    ] as [(Double?, String)])
    func labelReadsTheStockAfterThePrice(rating: Double?, expected: String) {
        let label = ProductCardAccessibility.label(
            title: "Volume Mascara",
            price: "$9.99",
            stock: "Low stock, 4 left",
            rating: rating,
            isSaved: false,
            locale: Self.english
        )

        #expect(label == expected)
    }

    @Test func labelUsesTheLocalesDecimalSeparator() {
        let label = ProductCardAccessibility.label(title: "Volume Mascara", price: "9,99 $", stock: nil, rating: 4.56, isSaved: false, locale: Locale(identifier: "de_DE"))

        #expect(label.contains("rated 4,6 of 5"))
    }

    @Test func saveActionNameSaysWhatItDoes() {
        #expect(ProductCardAccessibility.saveActionName(isSaved: false) == "Save")
        #expect(ProductCardAccessibility.saveActionName(isSaved: true) == "Remove from Saved")
    }
}
