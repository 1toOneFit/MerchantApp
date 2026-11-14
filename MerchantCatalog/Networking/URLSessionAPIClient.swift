import Foundation

/// The only type that touches `URLSession` (Networking.md § 2).
///
/// - No caching (D-10): its configuration has `urlCache = nil` and
///   `requestCachePolicy = .reloadIgnoringLocalCacheData`, and every request uses that policy too.
/// - No automatic retries: retries are user-initiated.
/// - `request(_:)` runs off the main actor (`@concurrent`), so building, decoding and logging never
///   block the UI. Cancelling the calling task cancels the `URLSession` task.
final class URLSessionAPIClient: APIClientType {
    /// Exposed so tests can check the no-cache configuration.
    let session: URLSession
    /// Exposed so tests can check that the DEBUG slow-network toggle reaches the client.
    let delay: RequestDelay
    private let decoder = JSONDecoder()

    /// - Parameters:
    ///   - configuration: taken over by the client, which turns its cache off.
    ///   - delay: read on every request; the DEBUG slow-network toggle sets it.
    init(configuration: URLSessionConfiguration = .default, delay: RequestDelay = RequestDelay()) {
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
        self.delay = delay
    }

    @concurrent
    func request<Response: Decodable & Sendable>(_ target: some TargetType) async throws -> Response {
        let request = try Self.makeRequest(for: target, delay: delay.value)
        let id = NetworkLogger.makeRequestID()
        let start = ContinuousClock.now
        NetworkLogger.started(request, id: id)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let latency = start.duration(to: .now)
            if Self.isCancellation(error) {
                NetworkLogger.cancelled(id: id, latency: latency)
                throw CancellationError()
            }
            let appError = (error as? URLError).map(Self.appError(for:)) ?? .unknown
            NetworkLogger.failed(id: id, error: appError, cause: NetworkLogger.summary(of: error), latency: latency)
            throw appError
        }

        let latency = start.duration(to: .now)
        guard let http = response as? HTTPURLResponse else {
            NetworkLogger.failed(id: id, error: .unknown, cause: "not an HTTP response", latency: latency)
            throw AppError.unknown
        }
        NetworkLogger.received(id: id, status: http.statusCode, latency: latency, bytes: data.count)
        NetworkLogger.responseDetails(http, body: data, id: id)
        if let error = Self.appError(forStatus: http.statusCode) {
            throw error
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            NetworkLogger.failed(id: id, error: .decoding, cause: NetworkLogger.summary(of: error), latency: latency)
            throw AppError.decoding
        }
    }

    /// Builds the `URLRequest` for `target`, appending `delay=<ms>` when `delay` is set.
    ///
    /// - Throws: `AppError.unknown` if the target doesn't form a valid URL.
    static func makeRequest(for target: some TargetType, delay: Duration?) throws -> URLRequest {
        var queryItems = target.queryItems
        if let delay {
            queryItems.append(URLQueryItem(name: "delay", value: String(delay.wholeMilliseconds)))
        }
        guard var components = URLComponents(
            url: target.baseURL.appending(path: target.path),
            resolvingAgainstBaseURL: false
        ) else {
            throw AppError.unknown
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        // `URLComponents` leaves `+` unencoded, and the API decodes it as a space (Networking.md A13).
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else {
            throw AppError.unknown
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: target.timeout)
        request.httpMethod = target.method.rawValue
        for (field, value) in target.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    /// Also used by `URLSessionImageLoader`.
    static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    /// Transport errors (Networking.md § 2); codes outside the table are `.unknown` (D-43).
    static func appError(for error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: .offline
        case .timedOut: .timeout
        default: .unknown
        }
    }

    /// `nil` for 2xx; otherwise the status's error.
    static func appError(forStatus status: Int) -> AppError? {
        switch status {
        case 200..<300: nil
        case 404: .notFound
        case 429: .rateLimited
        default: .server(status: status)
        }
    }
}
