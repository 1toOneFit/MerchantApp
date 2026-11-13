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
}
