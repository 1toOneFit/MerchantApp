#if DEBUG
import Foundation
import Testing
@testable import MerchantCatalog

/// DEBUG-only extended network logging (D-80): the request's method, URL, query parameters,
/// headers and timeout; the response's status, type, size, headers and body. The search term stays
/// `<private>` (D-18), credential headers are redacted, JSON bodies are pretty-printed and split
/// into chunks small enough for one log message, image bodies aren't logged.
struct NetworkLogFormatterTests {
    private static func request(_ string: String, headers: [String: String] = [:], timeout: TimeInterval = 15) throws -> URLRequest {
        var request = URLRequest(url: try #require(URL(string: string)), timeoutInterval: timeout)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    private static func response(status: Int = 200, headers: [String: String]) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://dummyjson.com/products"))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers))
    }

    // MARK: Request

    @Test func requestShowsMethodURLQueryHeadersAndTimeout() throws {
        let request = try Self.request("https://dummyjson.com/products?limit=20&skip=0", headers: ["Accept": "application/json"])

        #expect(NetworkLogFormatter.requestLines(request) == [
            "request GET https://dummyjson.com/products?limit=20&skip=0",
            "query: limit=20, skip=0",
            "headers:",
            "  Accept: application/json",
            "timeout: 15 s",
            "body: none",
        ])
    }

    @Test func requestWithoutQueryOrHeadersSaysSo() throws {
        let lines = NetworkLogFormatter.requestLines(try Self.request("https://dummyjson.com/products/1"))

        #expect(lines.contains("query: none"))
        #expect(lines.contains("headers: none set by the app (URLSession adds its defaults when sending)"))
    }

    @Test func searchTermStaysPrivate() throws {
        let lines = NetworkLogFormatter.requestLines(try Self.request("https://dummyjson.com/products/search?q=red%20phone&limit=20"))

        #expect(lines.allSatisfy { !$0.contains("phone") })
        #expect(lines.contains("request GET https://dummyjson.com/products/search?q=<private>&limit=20"))
        #expect(lines.contains("query: q=<private>, limit=20"))
    }

    @Test func credentialHeadersAreRedacted() throws {
        let lines = NetworkLogFormatter.requestLines(try Self.request("https://dummyjson.com/products", headers: ["Authorization": "Bearer secret", "Cookie": "a=b"]))

        #expect(lines.contains("  Authorization: <redacted>"))
        #expect(lines.contains("  Cookie: <redacted>"))
        #expect(lines.allSatisfy { !$0.contains("secret") })
    }

    // MARK: Response

    @Test func responseShowsStatusTypeSizeAndSortedHeaders() throws {
        let response = try Self.response(headers: ["Content-Type": "application/json; charset=utf-8", "Etag": "W/\"1\"", "Set-Cookie": "id=1"])

        let lines = NetworkLogFormatter.responseLines(response, body: Data("{}".utf8))

        #expect(Array(lines.prefix(5)) == [
            "response 200, application/json, 2 bytes",
            "headers:",
            "  Content-Type: application/json; charset=utf-8",
            "  Etag: W/\"1\"",
            "  Set-Cookie: <redacted>",
        ])
    }

    @Test func jsonBodyIsPrettyPrintedWithSortedKeys() throws {
        let response = try Self.response(headers: ["Content-Type": "application/json"])

        let lines = NetworkLogFormatter.responseLines(response, body: Data(#"{"total":194,"limit":1}"#.utf8))

        #expect(lines.suffix(2) == [
            "body 1/1:",
            "{\n  \"limit\" : 1,\n  \"total\" : 194\n}",
        ])
    }

    /// Reviewer email is never logged (ProductSpecification § 4.3): any JSON key containing
    /// "email", at any depth, is redacted.
    @Test func emailsInJSONBodiesAreRedacted() throws {
        let response = try Self.response(headers: ["Content-Type": "application/json"])
        let body = Data(#"{"reviews":[{"rating":5,"reviewerEmail":"a.b@x.com","reviewerName":"A B"}]}"#.utf8)

        let text = NetworkLogFormatter.responseLines(response, body: body).joined(separator: "\n")

        #expect(!text.contains("a.b@x.com"))
        #expect(text.contains(#""reviewerEmail" : "<redacted>""#))
        #expect(text.contains(#""reviewerName" : "A B""#))
    }

    @Test func longBodyIsChunkedWithoutLoss() throws {
        let response = try Self.response(headers: ["Content-Type": "application/json"])
        let items = (0..<200).map { #"{"id":\#($0),"title":"Product \#($0)"}"# }.joined(separator: ",")
        let body = Data(#"{"products":[\#(items)]}"#.utf8)

        let lines = NetworkLogFormatter.responseLines(response, body: body)
        let bodyIndex = try #require(lines.firstIndex { $0.hasPrefix("body 1/") })
        let headers = lines[bodyIndex...].enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
        let chunks = lines[bodyIndex...].enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)

        #expect(chunks.count > 1)
        #expect(headers == (1...chunks.count).map { "body \($0)/\(chunks.count):" })
        #expect(chunks.allSatisfy { $0.utf8.count <= NetworkLogFormatter.maxChunkBytes })
        let pretty = try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: body), options: [.prettyPrinted, .sortedKeys])
        #expect(chunks.joined() == String(decoding: pretty, as: UTF8.self))
    }

    /// Chunks end after a line break when one fits, so log messages start at a line.
    @Test func chunksBreakAfterLineBreaks() {
        let chunks = NetworkLogFormatter.chunks("aaaa\nbbbb\ncccc", maxBytes: 11)

        #expect(chunks == ["aaaa\nbbbb\n", "cccc"])
    }

    @Test func multibyteTextIsChunkedByBytes() {
        let text = String(repeating: "★", count: 1_000)

        let chunks = NetworkLogFormatter.chunks(text, maxBytes: 100)

        #expect(chunks.allSatisfy { $0.utf8.count <= 100 })
        #expect(chunks.joined() == text)
    }

    @Test func nonJSONTextBodyIsLoggedAsText() throws {
        let response = try Self.response(status: 503, headers: ["Content-Type": "text/plain"])

        let lines = NetworkLogFormatter.responseLines(response, body: Data("Service Unavailable".utf8))

        #expect(lines.first == "response 503, text/plain, 19 bytes")
        #expect(lines.suffix(2) == ["body 1/1:", "Service Unavailable"])
    }

    @Test func imageBodyIsNotLogged() throws {
        let response = try Self.response(headers: ["Content-Type": "image/webp"])

        let lines = NetworkLogFormatter.responseLines(response, body: Data([0x52, 0x49, 0x46]))

        #expect(lines.last == "body: 3 bytes (image/webp), not logged")
    }

    @Test func emptyBodySaysSo() throws {
        let response = try Self.response(status: 404, headers: [:])

        #expect(NetworkLogFormatter.responseLines(response, body: Data()).last == "body: empty")
    }
}
#endif
