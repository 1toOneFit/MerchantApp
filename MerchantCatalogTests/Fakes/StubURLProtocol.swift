import Foundation
import Synchronization

/// Serves canned responses to a `URLSession` built from `Stub.makeConfiguration()`, so
/// `URLSessionAPIClient` runs its real request, status-mapping and decoding code without a network.
///
/// Each stub gets a unique host and requests are routed by host, so tests running in parallel
/// never see each other's responses.
final class StubURLProtocol: URLProtocol {
    enum Response: Sendable {
        /// An `HTTPURLResponse` with this status and body.
        case http(status: Int, body: Data)
        /// A plain `URLResponse` (not HTTP) with this body.
        case nonHTTP(body: Data)
        /// A transport failure, as `URLSession` reports it.
        case failure(URLError.Code)
        /// Never answers; the request ends only when it is cancelled.
        case never
    }

    final class Stub: Sendable {
        let host: String
        let response: Response
        private let state = Mutex(State())

        private struct State {
            var requests: [URLRequest] = []
            var waiters: [CheckedContinuation<Void, Never>] = []
        }

        fileprivate init(host: String, response: Response) {
            self.host = host
            self.response = response
        }

        /// Requests the stub received, oldest first.
        var requests: [URLRequest] {
            state.withLock { $0.requests }
        }

        /// An ephemeral configuration whose only protocol class is `StubURLProtocol`.
        func makeConfiguration() -> URLSessionConfiguration {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubURLProtocol.self]
            return configuration
        }

        /// Returns once the stub has received at least one request.
        func waitForRequest() async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let hasRequest = state.withLock { state in
                    if !state.requests.isEmpty { return true }
                    state.waiters.append(continuation)
                    return false
                }
                if hasRequest { continuation.resume() }
            }
        }

        fileprivate func record(_ request: URLRequest) {
            let waiters = state.withLock { state in
                state.requests.append(request)
                let waiters = state.waiters
                state.waiters = []
                return waiters
            }
            waiters.forEach { $0.resume() }
        }
    }

    private static let stubs = Mutex<[String: Stub]>([:])

    /// Registers `response` under a new unique host; build targets with `https://<stub.host>`.
    static func register(_ response: Response) -> Stub {
        let stub = Stub(host: "\(UUID().uuidString.lowercased()).stub.test", response: response)
        stubs.withLock { $0[stub.host] = stub }
        return stub
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let url = request.url,
            let host = url.host(),
            let stub = Self.stubs.withLock({ $0[host] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        stub.record(request)

        switch stub.response {
        case .http(let status, let body):
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            finish(with: response, body: body)
        case .nonHTTP(let body):
            let response = URLResponse(url: url, mimeType: "application/json", expectedContentLength: body.count, textEncodingName: nil)
            finish(with: response, body: body)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .never:
            break
        }
    }

    override func stopLoading() {}

    private func finish(with response: URLResponse, body: Data) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
