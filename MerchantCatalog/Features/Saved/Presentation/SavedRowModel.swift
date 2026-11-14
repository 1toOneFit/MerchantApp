import Foundation

/// What a Saved row shows: thumbnail, title, price when saved and saved date, labeled as saved
/// information. No rating: the row is the same in both experiment arms (ProductSpecification § 4.4).
struct SavedRowModel: Identifiable, Equatable {
    let id: Int
    let title: String
    let thumbnailURL: URL?
    /// "Price when saved: $9.99".
    let priceWhenSaved: String
    /// "Saved 3 Nov".
    let savedDate: String

    init(_ item: SavedProduct, locale: Locale = .current, timeZone: TimeZone = .current) {
        id = item.id
        title = item.summary.title
        thumbnailURL = item.summary.thumbnailURL
        priceWhenSaved = SavedProductFormat.priceWhenSaved(item.summary.price, locale: locale)
        savedDate = SavedProductFormat.savedDate(item.savedAt, locale: locale, timeZone: timeZone)
    }
}
