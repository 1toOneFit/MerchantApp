import Foundation
import Testing
@testable import MerchantCatalog

private struct Echo: Decodable, Equatable, Sendable {
    let value: Int
}

/// A target served by a `StubURLProtocol.Stub` (routed by its unique host).
private struct StubTarget: TargetType {
    let host: String

    var baseURL: URL {
        guard let url = URL(string: "https://\(host)") else {
            preconditionFailure("invalid stub host \(host)")
        }
        return url
    }

    var path: String { "/echo" }
}

/// `URLSessionAPIClient` against `StubURLProtocol`: request building, no caching, status and
/// transport-error mapping (Networking.md § 2, D-43), decoding and cancellation.
struct URLSessionAPIClientTests {
    private static let echoBody = Data(#"{"value": 7}"#.utf8)

    private static func request(
        _ stub: StubURLProtocol.Stub,
        delay: RequestDelay = RequestDelay()
    ) async throws -> Echo {
        let client = URLSessionAPIClient(configuration: stub.makeConfiguration(), delay: delay)
        return try await client.request(StubTarget(host: stub.host))
    }

    @Test func decodesA2xxResponse() async throws {
        let stub = StubURLProtocol.register(.http(status: 200, body: Self.echoBody))

        #expect(try await Self.request(stub) == Echo(value: 7))
    }

    @Test(arguments: [
        (404, AppError.notFound),
        (429, .rateLimited),
        (500, .server(status: 500)),
        (503, .server(status: 503)),
        (400, .server(status: 400)),
    ])
    func mapsHTTPStatus(status: Int, expected: AppError) async {
        let stub = StubURLProtocol.register(.http(status: status, body: Data(#"{"message":"x"}"#.utf8)))

        await #expect(throws: expected) {
            try await Self.request(stub)
        }
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, AppError.offline),
        (.networkConnectionLost, .offline),
        (.dataNotAllowed, .offline),
        (.timedOut, .timeout),
        (.cannotFindHost, .unknown),
    ])
    func mapsTransportErrors(code: URLError.Code, expected: AppError) async {
        let stub = StubURLProtocol.register(.failure(code))

        await #expect(throws: expected) {
            try await Self.request(stub)
        }
    }

    @Test func malformedJSONIsDecodingError() async {
        let stub = StubURLProtocol.register(.http(status: 200, body: Data(#"{"value": "seven"}"#.utf8)))

        await #expect(throws: AppError.decoding) {
            try await Self.request(stub)
        }
    }

    @Test func nonHTTPResponseIsUnknown() async {
        let stub = StubURLProtocol.register(.nonHTTP(body: Self.echoBody))

        await #expect(throws: AppError.unknown) {
            try await Self.request(stub)
        }
    }

    @Test func cancellationThrowsCancellationError() async {
        let stub = StubURLProtocol.register(.never)
        let task = Task {
            try await Self.request(stub)
        }

        await stub.waitForRequest()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func requestUsesNoCache() async throws {
        let stub = StubURLProtocol.register(.http(status: 200, body: Self.echoBody))
        let client = URLSessionAPIClient(configuration: stub.makeConfiguration())

        let _: Echo = try await client.request(StubTarget(host: stub.host))

        #expect(client.session.configuration.urlCache == nil)
        #expect(client.session.configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        let request = try #require(stub.requests.first)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test func buildsRequestFromTarget() throws {
        let request = try URLSessionAPIClient.makeRequest(
            for: ProductsTarget.list(skip: 0, limit: 20, sort: .defaultOrder),
            delay: nil
        )

        #expect(request.url?.absoluteString == "https://dummyjson.com/products?limit=20&skip=0&select=title,price,thumbnail,rating,category,stock")
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 15)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    /// AC-S3: search, sort and pagination travel together in one request (Networking.md A3).
    @Test func buildsSearchRequestWithSortAndPage() throws {
        let request = try URLSessionAPIClient.makeRequest(
            for: ProductsTarget.search(query: "phone", skip: 20, limit: 20, sort: .priceDescending),
            delay: nil
        )

        #expect(request.url?.absoluteString == "https://dummyjson.com/products/search?q=phone&limit=20&skip=20&select=title,price,thumbnail,rating,category,stock&sortBy=price&order=desc")
    }

    /// The API decodes `+` as a space (A13) and `URLComponents` leaves it unencoded, so `+` is sent
    /// as `%2B`; `&`, `=` and spaces must not split or end the value either (D-51).
    @Test func searchQueryIsPercentEncoded() throws {
        let request = try URLSessionAPIClient.makeRequest(
            for: ProductsTarget.search(query: "a+b & c=d", skip: 0, limit: 20, sort: .defaultOrder),
            delay: nil
        )

        #expect(request.url?.absoluteString == "https://dummyjson.com/products/search?q=a%2Bb%20%26%20c%3Dd&limit=20&skip=0&select=title,price,thumbnail,rating,category,stock")
    }

    @Test func slowNetworkDelayAddsQueryItem() throws {
        let request = try URLSessionAPIClient.makeRequest(
            for: ProductsTarget.list(skip: 0, limit: 20, sort: .defaultOrder),
            delay: .milliseconds(2000)
        )

        #expect(request.url?.absoluteString == "https://dummyjson.com/products?limit=20&skip=0&select=title,price,thumbnail,rating,category,stock&delay=2000")
    }

    /// The client reads the shared `RequestDelay` on every request, so the DEBUG toggle applies
    /// without rebuilding the client.
    @Test func requestDelayIsReadPerRequest() async throws {
        let stub = StubURLProtocol.register(.http(status: 200, body: Self.echoBody))
        let delay = RequestDelay()
        let client = URLSessionAPIClient(configuration: stub.makeConfiguration(), delay: delay)

        let _: Echo = try await client.request(StubTarget(host: stub.host))
        delay.set(.milliseconds(2000))
        let _: Echo = try await client.request(StubTarget(host: stub.host))

        #expect(stub.requests.map { $0.url?.query() } == [nil, "delay=2000"])
    }
}
