import Testing
@testable import MerchantCatalog

/// A search query is the trimmed field text; whitespace alone is no query (ProductSpecification
/// § 4.2). Length and word count are what analytics may know about it (D-18, D-49).
struct SearchQueryTests {
    @Test func trimsWhitespace() {
        #expect(SearchQuery("  phone \n")?.text == "phone")
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func blankIsNil(rawText: String) {
        #expect(SearchQuery(rawText) == nil)
    }

    @Test(arguments: [
        ("phone", 5, 1),
        ("red  shoes", 10, 2),
        ("  café  latte\n", 11, 2),
    ])
    func lengthAndWordCount(rawText: String, length: Int, wordCount: Int) throws {
        let query = try #require(SearchQuery(rawText))

        #expect(query.length == length)
        #expect(query.wordCount == wordCount)
    }
}
