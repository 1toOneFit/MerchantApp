import Foundation
import OSLog

/// Request logging in the `network` category (Architecture § 10): method, sanitized URL, a short
/// request id, status, latency, size, errors and cancellation. DEBUG builds log every request and
/// response field instead, as framed boxes for API requests and one line per image request
/// (`NetworkLogFormatter`, D-80). Success and cancellation log at
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

    /// How much a request logs in DEBUG builds (D-80). Release builds log the same one-line
    /// summaries for both.
    enum Style: Sendable {
        /// API requests: a framed REQUEST box at the start, a framed RESPONSE box at the end.
        case detailed
        /// Image requests: one line at the end.
        case compact
    }

    static func started(_ request: URLRequest, id: String, style: Style) {
        #if DEBUG
        if style == .detailed {
            emit(NetworkLogFormatter.requestBox(request, id: id), isError: false)
        }
        #else
        let method = request.httpMethod ?? "GET"
        let url = request.url.map(sanitizedURL) ?? "nil"
        Log.network.debug("[\(id, privacy: .public)] \(method, privacy: .public) \(url, privacy: .public)")
        #endif
    }

    static func received(_ request: URLRequest, response: HTTPURLResponse, body: Data, id: String, latency: Duration, style: Style) {
        let isError = !(200..<300).contains(response.statusCode)
        #if DEBUG
        switch style {
        case .detailed:
            emit(NetworkLogFormatter.responseBox(response, body: body, id: id, latency: latency), isError: isError)
        case .compact:
            let outcome = "\(response.statusCode) · \(latency.wholeMilliseconds) ms · \(body.count) bytes \(response.mimeType ?? "unknown type")"
            emit([compactLine(request, id: id, outcome: outcome)], isError: isError)
        }
        #else
        let line = "[\(id)] \(response.statusCode) in \(latency.wholeMilliseconds) ms, \(body.count) bytes"
        emit([line], isError: isError)
        #endif
    }

    /// - Parameter cause: `summary(of:)` of the underlying error, or a fixed reason.
    static func failed(_ request: URLRequest, id: String, error: AppError, cause: String, latency: Duration, style: Style) {
        let outcome = "failed after \(latency.wholeMilliseconds) ms: \(error.analyticsErrorType) (\(cause))"
        emit(outcomeMessages(request, id: id, outcome: outcome, style: style), isError: true)
    }

    static func cancelled(_ request: URLRequest, id: String, latency: Duration, style: Style) {
        let outcome = "cancelled after \(latency.wholeMilliseconds) ms"
        emit(outcomeMessages(request, id: id, outcome: outcome, style: style), isError: false)
    }

    /// The end of a request without a usable response: a closing box (detailed), one line
    /// (compact), or Release's summary line.
    private static func outcomeMessages(_ request: URLRequest, id: String, outcome: String, style: Style) -> [String] {
        #if DEBUG
        switch style {
        case .detailed: NetworkLogFormatter.endBox(id: id, outcome: outcome)
        case .compact: [compactLine(request, id: id, outcome: outcome)]
        }
        #else
        ["[\(id)] \(outcome)"]
        #endif
    }

    #if DEBUG
    private static func compactLine(_ request: URLRequest, id: String, outcome: String) -> String {
        guard let url = request.url else { return "[\(id)] \(request.httpMethod ?? "GET") nil → \(outcome)" }
        return NetworkLogFormatter.compactLine(method: request.httpMethod ?? "GET", url: url, id: id, outcome: outcome)
    }
    #endif

    /// One log message each. The text is already sanitized (`q`, credentials and emails redacted,
    /// errors summarized), so it is logged as public. Errors at error level, the rest at debug.
    private static func emit(_ messages: [String], isError: Bool) {
        for message in messages {
            if isError {
                Log.network.error("\(message, privacy: .public)")
            } else {
                Log.network.debug("\(message, privacy: .public)")
            }
        }
    }
}
