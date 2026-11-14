import UIKit

/// Downloads product images with its own `URLSession` (Networking.md § 4, D-78).
///
/// - Cancellable: `image(from:)` awaits `URLSession.data(for:)`, so cancelling the calling task
///   (SwiftUI cancels `.task` when the image view disappears) cancels the request. The `network`
///   log shows each request's start and its end, including `cancelled after … ms`.
/// - No caching (D-10): `urlCache = nil` and `.reloadIgnoringLocalCacheData`, like
///   `URLSessionAPIClient`. A reappearing image downloads again.
/// - Off the main actor (`@concurrent`): the download and the decoding
///   (`byPreparingForDisplay()`) never block the UI.
final class URLSessionImageLoader: ImageLoading {
    /// Exposed so tests can check the no-cache configuration.
    let session: URLSession

    /// - Parameter configuration: taken over by the loader, which turns its cache off.
    init(configuration: URLSessionConfiguration = .default) {
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    @concurrent
    func image(from url: URL) async throws -> UIImage {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let id = NetworkLogger.makeRequestID()
        let start = ContinuousClock.now
        NetworkLogger.started(request, id: id)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let latency = start.duration(to: .now)
            if URLSessionAPIClient.isCancellation(error) {
                NetworkLogger.cancelled(id: id, latency: latency)
                throw CancellationError()
            }
            let appError = (error as? URLError).map(URLSessionAPIClient.appError(for:)) ?? .unknown
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
        if let error = URLSessionAPIClient.appError(forStatus: http.statusCode) {
            throw error
        }
        guard let image = UIImage(data: data) else {
            NetworkLogger.failed(id: id, error: .decoding, cause: "not an image", latency: latency)
            throw AppError.decoding
        }
        return await image.byPreparingForDisplay() ?? image
    }
}
