import Foundation

/// How a snapshot is labeled as saved information wherever it shows (ProductSpecification § 4.4):
/// the Saved row and details opened from Saved.
enum SavedProductFormat {
    /// "Price when saved: $9.99" (the demo price in USD, with the locale's number formatting).
    static func priceWhenSaved(_ price: Decimal, locale: Locale = .current) -> String {
        "Price when saved: \(price.formatted(.currency(code: "USD").locale(locale)))"
    }

    /// "Saved 3 Nov": day and abbreviated month in the locale's order.
    static func savedDate(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let style = Date.FormatStyle(locale: locale, timeZone: timeZone).day().month(.abbreviated)
        return "Saved \(date.formatted(style))"
    }
}
