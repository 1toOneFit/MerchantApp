import Foundation

/// What VoiceOver says for a catalog card (ProductSpecification § 4.5): one element,
/// "Title, price[, stock][, rating], saved/not saved", with a custom action to save or unsave. The
/// visible save button stays a separate touch target (D-60); VoiceOver reaches it through the action.
enum ProductCardAccessibility {
    /// `stock`: the stock label's spoken text (D-86); `nil` when unknown. `rating`: only when the
    /// card shows one (S6's treatment arm); `nil` leaves it out.
    static func label(title: String, price: String, stock: String?, rating: Double?, isSaved: Bool, locale: Locale = .current) -> String {
        var parts = [title, price]
        if let stock {
            parts.append(stock)
        }
        if let rating {
            parts.append("rated \(rating.formatted(.number.precision(.fractionLength(1)).locale(locale))) of 5")
        }
        parts.append(isSaved ? "saved" : "not saved")
        return parts.joined(separator: ", ")
    }

    /// The custom action's name says what it does, like the save button's label.
    static func saveActionName(isSaved: Bool) -> String {
        SaveButton.title(isSaved: isSaved)
    }
}
