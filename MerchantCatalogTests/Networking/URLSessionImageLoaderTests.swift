import Foundation
import Testing
import UIKit
@testable import MerchantCatalog

/// `URLSessionImageLoader` against `StubURLProtocol`: decoding, no caching, error mapping, and
/// cancellation that reaches the `URLSession` task (Networking.md § 4, D-78).
@Suite(.timeLimit(.minutes(1)))
struct URLSessionImageLoaderTests {
    /// A 2 × 3 pt opaque PNG at scale 1.
    private static let png: Data = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 2, height: 3), format: format).pngData { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 3))
        }
    }()

    private static func url(_ stub: StubURLProtocol.Stub) throws -> URL {
        try #require(URL(string: "https://\(stub.host)/image.webp"))
    }

    private static func load(_ stub: StubURLProtocol.Stub) async throws -> UIImage {
        let loader = URLSessionImageLoader(configuration: stub.makeConfiguration())
        return try await loader.image(from: url(stub))
    }

    @Test func decodesAnImage() async throws {
        let stub = StubURLProtocol.register(.http(status: 200, body: Self.png))

        let image = try await Self.load(stub)

        #expect(image.size.width * image.scale == 2)
        #expect(image.size.height * image.scale == 3)
        #expect(stub.requests.first?.url == (try Self.url(stub)))
    }

    /// Cancelling the loading task cancels the `URLSession` task: the stub's load is stopped while
    /// it was still waiting for a response, and the caller gets `CancellationError`.
    @Test func cancellationStopsTheRequest() async throws {
        let stub = StubURLProtocol.register(.never)
        let task = Task { try await Self.load(stub) }

        await stub.waitForRequest()
        #expect(stub.stopCount == 0)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        await stub.waitForStop()
        #expect(stub.stopCount == 1)
    }

    @Test func requestUsesNoCache() async throws {
        let stub = StubURLProtocol.register(.http(status: 200, body: Self.png))
        let loader = URLSessionImageLoader(configuration: stub.makeConfiguration())

        _ = try await loader.image(from: Self.url(stub))

        #expect(loader.session.configuration.urlCache == nil)
        #expect(loader.session.configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(stub.requests.first?.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test(arguments: [
        (StubURLProtocol.Response.http(status: 404, body: Data()), AppError.notFound),
        (.http(status: 503, body: Data()), .server(status: 503)),
        (.http(status: 200, body: Data("not an image".utf8)), .decoding),
        (.failure(.notConnectedToInternet), .offline),
        (.failure(.timedOut), .timeout),
    ])
    func failuresMapToAppError(response: StubURLProtocol.Response, expected: AppError) async throws {
        let stub = StubURLProtocol.register(response)

        await #expect(throws: expected) {
            try await Self.load(stub)
        }
    }
}
