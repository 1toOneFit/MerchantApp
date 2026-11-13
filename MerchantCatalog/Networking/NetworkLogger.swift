import Foundation
import OSLog

/// Request logging in the `network` category (Architecture § 10): method, sanitized URL, a short
/// request id, status, latency, size, errors and cancellation. Success and cancellation log at
/// debug level, failures at error level. The search term (`q`) is redacted before logging (D-18),
/// so the rest of the URL is logged as public.
enum NetworkLogger {
    /// `url` as text with the value of `q` replaced by `<private>`.
    static func sanitizedURL(_ url: URL) -> String {
        guard
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let items = components.percentEncodedQueryItems,
            items.contains(where: { $0.name == "q" })
        else {
            return url.absoluteString
        }
        let query = items
            .map { item in
                if item.name == "q" { return "q=<private>" }
                return item.value.map { "\(item.name)=\($0)" } ?? item.name
            }
            .joined(separator: "&")
        components.percentEncodedQuery = nil
        return "\(components.string ?? "")?\(query)"
    }

    /// Eight characters that tie a request's log lines together.
    static func makeRequestID() -> String {
        String(UUID().uuidString.prefix(8)).lowercased()
    }

    static func started(_ request: URLRequest, id: String) {
        let method = request.httpMethod ?? "GET"
        let url = request.url.map(sanitizedURL) ?? "nil"
        Log.network.debug("[\(id, privacy: .public)] \(method, privacy: .public) \(url, privacy: .public)")
    }

    static func received(id: String, status: Int, latency: Duration, bytes: Int) {
        let ms = latency.wholeMilliseconds
        if (200..<300).contains(status) {
            Log.network.debug("[\(id, privacy: .public)] \(status, privacy: .public) in \(ms, privacy: .public) ms, \(bytes, privacy: .public) bytes")
        } else {
            Log.network.error("[\(id, privacy: .public)] \(status, privacy: .public) in \(ms, privacy: .public) ms, \(bytes, privacy: .public) bytes")
        }
    }

    static func failed(id: String, error: AppError, underlying: String, latency: Duration) {
        let ms = latency.wholeMilliseconds
        Log.network.error("[\(id, privacy: .public)] failed in \(ms, privacy: .public) ms: \(String(describing: error), privacy: .public) (\(underlying, privacy: .public))")
    }

    static func cancelled(id: String, latency: Duration) {
        let ms = latency.wholeMilliseconds
        Log.network.debug("[\(id, privacy: .public)] cancelled after \(ms, privacy: .public) ms")
    }
}
