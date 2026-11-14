import Foundation
import OSLog

/// Request logging in the `network` category (Architecture § 10): method, sanitized URL, a short
/// request id, status, latency, size, errors and cancellation. DEBUG builds add every request and
/// response field: query, headers, timeout, response headers and the body (`NetworkLogFormatter`,
/// D-80). Success and cancellation log at
/// debug level, failures at error level. The search term (`q`) is redacted before logging (D-18),
/// so the rest of the URL is logged as public. Errors are logged as a code or category only
/// (`summary(of:)`), never as their description, which can contain the full request URL.
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

    /// A loggable description of `error` without URLs or payload values: `URLError -1009`,
    /// `DecodingError.typeMismatch at products.0.price`, or the error's type name.
    static func summary(of error: any Error) -> String {
        if let error = error as? URLError {
            return "URLError \(error.code.rawValue)"
        }
        if let error = error as? DecodingError {
            return decodingSummary(error)
        }
        return String(reflecting: type(of: error))
    }

    private static func decodingSummary(_ error: DecodingError) -> String {
        let (kind, path): (String, [any CodingKey]) = switch error {
        case .typeMismatch(_, let context): ("typeMismatch", context.codingPath)
        case .valueNotFound(_, let context): ("valueNotFound", context.codingPath)
        case .keyNotFound(let key, let context): ("keyNotFound", context.codingPath + [key])
        case .dataCorrupted(let context): ("dataCorrupted", context.codingPath)
        @unknown default: ("unknown", [])
        }
        let keys = path.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
        return keys.isEmpty ? "DecodingError.\(kind)" : "DecodingError.\(kind) at \(keys)"
    }

    /// Eight characters that tie a request's log lines together.
    static func makeRequestID() -> String {
        String(UUID().uuidString.prefix(8)).lowercased()
    }

    static func started(_ request: URLRequest, id: String) {
        let method = request.httpMethod ?? "GET"
        let url = request.url.map(sanitizedURL) ?? "nil"
        Log.network.debug("[\(id, privacy: .public)] \(method, privacy: .public) \(url, privacy: .public)")
        #if DEBUG
        details(NetworkLogFormatter.requestLines(request), id: id)
        #endif
    }

    /// DEBUG builds: the response's status, type, size, headers and body (D-80). Release logs only
    /// the `received` summary line.
    static func responseDetails(_ response: HTTPURLResponse, body: Data, id: String) {
        #if DEBUG
        details(NetworkLogFormatter.responseLines(response, body: body), id: id)
        #endif
    }

    #if DEBUG
    /// One debug-level message per line, each tagged with the request id. The lines are already
    /// sanitized (`q` and credentials redacted), so they are logged as public.
    private static func details(_ lines: [String], id: String) {
        for line in lines {
            Log.network.debug("[\(id, privacy: .public)] \(line, privacy: .public)")
        }
    }
    #endif

    static func received(id: String, status: Int, latency: Duration, bytes: Int) {
        let ms = latency.wholeMilliseconds
        if (200..<300).contains(status) {
            Log.network.debug("[\(id, privacy: .public)] \(status, privacy: .public) in \(ms, privacy: .public) ms, \(bytes, privacy: .public) bytes")
        } else {
            Log.network.error("[\(id, privacy: .public)] \(status, privacy: .public) in \(ms, privacy: .public) ms, \(bytes, privacy: .public) bytes")
        }
    }

    /// - Parameter cause: `summary(of:)` of the underlying error, or a fixed reason.
    static func failed(id: String, error: AppError, cause: String, latency: Duration) {
        let ms = latency.wholeMilliseconds
        Log.network.error("[\(id, privacy: .public)] failed in \(ms, privacy: .public) ms: \(error.analyticsErrorType, privacy: .public) (\(cause, privacy: .public))")
    }

    static func cancelled(id: String, latency: Duration) {
        let ms = latency.wholeMilliseconds
        Log.network.debug("[\(id, privacy: .public)] cancelled after \(ms, privacy: .public) ms")
    }
}
