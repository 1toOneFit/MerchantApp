#if DEBUG
import Foundation
import Testing
@testable import MerchantCatalog

/// DEBUG-only extended network logging (D-80): an API request is a framed REQUEST box when it
/// starts and a framed RESPONSE box when it ends; an image request is one line when it ends. The
/// search term stays `<private>` (D-18), credential headers and emails are redacted, JSON bodies are
/// pretty-printed, and a box longer than one log message is split at line breaks into several
/// messages (the unified log cuts a message at about 1 KB, measured 2026-11-14).
struct NetworkLogFormatterTests {
    private static let id = "c309e10f"
    private static let close = "└" + String(repeating: "─", count: 40)

    private static func request(_ string: String, headers: [String: String] = [:], timeout: TimeInterval = 60) throws -> URLRequest {
        var request = URLRequest(url: try #require(URL(string: string)), timeoutInterval: timeout)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    private static func response(status: Int = 200, headers: [String: String]) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://dummyjson.com/products"))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers))
    }

    /// The box as one text: its messages joined (each message is a run of whole lines).
    private static func text(_ messages: [String]) -> String {
        messages.joined(separator: "\n")
    }

    // MARK: Request box

    @Test func requestBoxShowsMethodURLQueryHeadersTimeoutAndBody() throws {
        let request = try Self.request("https://dummyjson.com/products?limit=20&skip=0", headers: ["Accept": "application/json"])

        #expect(NetworkLogFormatter.requestBox(request, id: Self.id) == [[
            "┌──── → REQUEST [c309e10f] ────",
            "│ GET https://dummyjson.com/products?limit=20&skip=0",
            "│ Query    limit=20, skip=0",
            "│ Headers",
            "│   Accept: application/json",
            "│ Timeout  60 s",
            "│ Body     none",
            Self.close,
        ].joined(separator: "\n")])
    }

    @Test func requestWithoutQueryOrHeadersSaysSo() throws {
        let text = Self.text(NetworkLogFormatter.requestBox(try Self.request("https://dummyjson.com/products/1"), id: Self.id))

        #expect(text.contains("│ Query    none"))
        #expect(text.contains("│ Headers  none set by the app (URLSession adds its defaults when sending)"))
    }

    @Test func searchTermStaysPrivate() throws {
        let request = try Self.request("https://dummyjson.com/products/search?q=red%20phone&limit=20")

        let text = Self.text(NetworkLogFormatter.requestBox(request, id: Self.id))

        #expect(!text.contains("phone"))
        #expect(text.contains("│ GET https://dummyjson.com/products/search?q=<private>&limit=20"))
        #expect(text.contains("│ Query    q=<private>, limit=20"))
    }

    @Test func credentialHeadersAreRedacted() throws {
        let request = try Self.request("https://dummyjson.com/products", headers: ["Authorization": "Bearer secret", "Cookie": "a=b"])

        let text = Self.text(NetworkLogFormatter.requestBox(request, id: Self.id))

        #expect(text.contains("│   Authorization: <redacted>"))
        #expect(text.contains("│   Cookie: <redacted>"))
        #expect(!text.contains("secret"))
    }

    // MARK: Response box

    @Test func responseBoxShowsStatusTimingTypeSizeHeadersAndPrettyBody() throws {
        let response = try Self.response(headers: ["Content-Type": "application/json; charset=utf-8", "Set-Cookie": "id=1"])

        let messages = NetworkLogFormatter.responseBox(response, body: Data(#"{"total":194,"limit":1}"#.utf8), id: Self.id, latency: .milliseconds(34))

        #expect(messages == [[
            "┌──── ← RESPONSE [c309e10f] 200 · 34 ms ────",
            "│ application/json · 23 bytes",
            "│ Headers",
            "│   Content-Type: application/json; charset=utf-8",
            "│   Set-Cookie: <redacted>",
            "│ Body",
            "│ {",
            "│   \"limit\" : 1,",
            "│   \"total\" : 194",
            "│ }",
            Self.close,
        ].joined(separator: "\n")])
    }

    /// A long box goes out as several messages, each under the log's limit and made of whole lines,
    /// so the frame continues from one message to the next and nothing is lost.
    @Test func longBoxIsSplitAtLineBreaksWithoutLoss() throws {
        let response = try Self.response(headers: ["Content-Type": "application/json"])
        let items = (0..<200).map { #"{"id":\#($0),"title":"Product \#($0)"}"# }.joined(separator: ",")

        let messages = NetworkLogFormatter.responseBox(response, body: Data(#"{"products":[\#(items)]}"#.utf8), id: Self.id, latency: .milliseconds(5))

        #expect(messages.count > 1)
        #expect(messages.allSatisfy { $0.utf8.count <= NetworkLogFormatter.maxMessageBytes })
        #expect(messages.first?.hasPrefix("┌──── ← RESPONSE [c309e10f] 200 · 5 ms") == true)
        #expect(messages.last?.hasSuffix(Self.close) == true)
        let lines = Self.text(messages).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.dropFirst().allSatisfy { $0.hasPrefix("│") || $0 == Self.close[...] })
        #expect(lines.contains("│       \"id\" : 199,"))
    }

    /// Reviewer email is never logged (ProductSpecification § 4.3).
    @Test func emailsInJSONBodiesAreRedacted() throws {
        let response = try Self.response(headers: ["Content-Type": "application/json"])
        let body = Data(#"{"reviews":[{"rating":5,"reviewerEmail":"a.b@x.com","reviewerName":"A B"}]}"#.utf8)

        let text = Self.text(NetworkLogFormatter.responseBox(response, body: body, id: Self.id, latency: .zero))

        #expect(!text.contains("a.b@x.com"))
        #expect(text.contains(#""reviewerEmail" : "<redacted>""#))
        #expect(text.contains(#""reviewerName" : "A B""#))
    }

    @Test func nonJSONTextBodyIsLoggedAsText() throws {
        let response = try Self.response(status: 503, headers: ["Content-Type": "text/plain"])

        let text = Self.text(NetworkLogFormatter.responseBox(response, body: Data("Service Unavailable".utf8), id: Self.id, latency: .milliseconds(7)))

        #expect(text.hasPrefix("┌──── ← RESPONSE [c309e10f] 503 · 7 ms ────\n│ text/plain · 19 bytes"))
        #expect(text.contains("│ Body\n│ Service Unavailable\n"))
    }

    @Test func binaryBodyIsNotLogged() throws {
        let response = try Self.response(headers: ["Content-Type": "application/octet-stream"])

        let text = Self.text(NetworkLogFormatter.responseBox(response, body: Data([1, 2, 3]), id: Self.id, latency: .zero))

        #expect(text.contains("│ Body     3 bytes (application/octet-stream), not logged"))
    }

    @Test func emptyBodyAndNoHeadersSaySo() throws {
        let response = try Self.response(status: 404, headers: [:])

        let text = Self.text(NetworkLogFormatter.responseBox(response, body: Data(), id: Self.id, latency: .zero))

        #expect(text.contains("│ Headers  none"))
        #expect(text.contains("│ Body     empty"))
    }

    @Test func endWithoutResponseIsAClosedBox() {
        #expect(NetworkLogFormatter.endBox(id: Self.id, outcome: "cancelled after 12 ms") == [
            "┌──── ← RESPONSE [c309e10f] cancelled after 12 ms ────\n" + Self.close,
        ])
    }

    // MARK: Image line

    @Test func imageLineSummarizesTheWholeRequest() throws {
        let url = try #require(URL(string: "https://cdn.dummyjson.com/product-images/beauty/mascara/1.webp"))

        #expect(NetworkLogFormatter.compactLine(method: "GET", url: url, id: Self.id, outcome: "200 · 34 ms · 63250 bytes image/webp")
            == "[c309e10f] GET https://cdn.dummyjson.com/product-images/beauty/mascara/1.webp → 200 · 34 ms · 63250 bytes image/webp")
    }

    // MARK: Splitting

    @Test func chunksBreakAfterLineBreaks() {
        #expect(NetworkLogFormatter.chunks("aaaa\nbbbb\ncccc", maxBytes: 11) == ["aaaa\nbbbb\n", "cccc"])
    }

    @Test func multibyteTextIsChunkedByBytes() {
        let text = String(repeating: "★", count: 1_000)

        let chunks = NetworkLogFormatter.chunks(text, maxBytes: 100)

        #expect(chunks.allSatisfy { $0.utf8.count <= 100 })
        #expect(chunks.joined() == text)
    }
}
#endif
