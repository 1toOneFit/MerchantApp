import Foundation

/// What the user is searching for: the search field's text without leading or trailing whitespace
/// (ProductSpecification § 4.2). Text that is only whitespace is no query, so the catalog shows
/// browse.
///
/// The text never leaves the app except as the request's `q` value; analytics get only `length`
/// and `wordCount` (D-18, D-49).
struct SearchQuery: Equatable, Sendable {
    let text: String

    init?(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        self.text = text
    }

    /// Characters in the trimmed text (`query_length`).
    var length: Int { text.count }

    /// Whitespace-separated words (`word_count`).
    var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }
}
