import Foundation
import Testing
@testable import MerchantCatalog

/// Request logs never contain search terms (D-18): the `q` value is redacted.
struct NetworkLoggerTests {
    @Test(arguments: [
        (
            "https://dummyjson.com/products/search?q=red%20shoes&limit=20",
            "https://dummyjson.com/products/search?q=<private>&limit=20"
        ),
        (
            "https://dummyjson.com/products?limit=20&skip=0",
            "https://dummyjson.com/products?limit=20&skip=0"
        ),
    ])
    func redactsSearchQuery(url: String, expected: String) throws {
        let url = try #require(URL(string: url))

        #expect(NetworkLogger.sanitizedURL(url) == expected)
    }

    @Test func requestIDsAreShortAndUnique() {
        let first = NetworkLogger.makeRequestID()
        let second = NetworkLogger.makeRequestID()

        #expect(first.count == 8)
        #expect(first != second)
    }

    /// Review finding 2: `URLError`'s description carries the failing URL (with a search term from
    /// S3 on), so failures are logged as a code or category only.
    @Test func urlErrorSummaryOmitsTheURL() throws {
        let url = try #require(URL(string: "https://dummyjson.com/products/search?q=secret-term"))
        let error = URLError(.notConnectedToInternet, userInfo: [NSURLErrorFailingURLErrorKey: url])

        let summary = NetworkLogger.summary(of: error)

        #expect(summary == "URLError -1009")
        #expect(!summary.contains("secret-term"))
    }

    @Test func decodingErrorSummaryNamesThePathOnly() throws {
        struct Price: Decodable { let price: Double }
        let data = Data(#"{"price": "secret-value"}"#.utf8)
        let error = try #require(throws: DecodingError.self) {
            try JSONDecoder().decode(Price.self, from: data)
        }

        let summary = NetworkLogger.summary(of: error)

        #expect(summary == "DecodingError.typeMismatch at price")
        #expect(!summary.contains("secret-value"))
    }

    @Test func otherErrorsAreSummarizedByType() {
        struct Unexpected: Error {
            let detail = "secret-detail"
        }

        let summary = NetworkLogger.summary(of: Unexpected())

        #expect(summary.hasSuffix("Unexpected"))
        #expect(!summary.contains("secret-detail"))
    }
}
