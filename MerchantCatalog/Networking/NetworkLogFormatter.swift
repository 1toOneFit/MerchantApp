#if DEBUG
import Foundation

/// DEBUG-only extended network logging (D-80, Architecture § 10): turns a request and its response
/// into log lines with every field the app can see. `NetworkLogger` prefixes each line with the
/// request id and logs it in the `network` category at debug level.
///
/// - Request: method and URL, query parameters, headers set by the app (`URLSession` adds its own
///   defaults, such as `User-Agent`, only when sending, so they don't appear), timeout, body.
/// - Response: status, MIME type, size, headers, body. JSON is pretty-printed with sorted keys;
///   text is logged as is; images and other binary bodies only by size and type.
/// - Privacy: the search term stays `q=<private>` (D-18); credential headers and every JSON value
///   under a key containing "email" (reviewer emails) are `<redacted>`.
/// - Size: bodies are split into chunks of at most `maxChunkBytes`, because the unified log is
///   expected to truncate long messages (not measured), so nothing is lost.
enum NetworkLogFormatter {
    /// The largest chunk of a body in one log message, in UTF-8 bytes.
    static let maxChunkBytes = 800

    private static let redactedHeaders: Set<String> = ["authorization", "proxy-authorization", "cookie", "set-cookie", "x-api-key"]

    static func requestLines(_ request: URLRequest) -> [String] {
        var lines = ["request \(request.httpMethod ?? "GET") \(request.url.map(NetworkLogger.sanitizedURL) ?? "nil")"]
        lines.append(queryLine(request.url))
        let headers = request.allHTTPHeaderFields ?? [:]
        lines += headers.isEmpty
            ? ["headers: none set by the app (URLSession adds its defaults when sending)"]
            : headerLines(headers)
        lines.append("timeout: \(String(format: "%g", request.timeoutInterval)) s")
        if let body = request.httpBody {
            lines += bodyLines(body, mimeType: request.value(forHTTPHeaderField: "Content-Type"))
        } else {
            lines.append("body: none")
        }
        return lines
    }

    static func responseLines(_ response: HTTPURLResponse, body: Data) -> [String] {
        var lines = ["response \(response.statusCode), \(response.mimeType ?? "unknown type"), \(body.count) bytes"]
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            headers["\(key)"] = "\(value)"
        }
        lines += headers.isEmpty ? ["headers: none"] : headerLines(headers)
        lines += bodyLines(body, mimeType: response.mimeType)
        return lines
    }

    /// `text` split into chunks of at most `maxBytes` UTF-8 bytes, never inside a character. A chunk
    /// ends after its last line break when one fits; `chunks(text).joined() == text`.
    static func chunks(_ text: String, maxBytes: Int = maxChunkBytes) -> [String] {
        var chunks: [String] = []
        var rest = Substring(text)
        while !rest.isEmpty {
            var end = rest.startIndex
            var bytes = 0
            var lastBreak: Substring.Index?
            while end < rest.endIndex {
                let size = rest[end].utf8.count
                if bytes + size > maxBytes { break }
                bytes += size
                if rest[end] == "\n" { lastBreak = rest.index(after: end) }
                end = rest.index(after: end)
            }
            if end < rest.endIndex, let lastBreak {
                end = lastBreak
            }
            if end == rest.startIndex {
                // A single character larger than the limit: emit it alone rather than loop.
                end = rest.index(after: end)
            }
            chunks.append(String(rest[..<end]))
            rest = rest[end...]
        }
        return chunks
    }

    private static func queryLine(_ url: URL?) -> String {
        guard
            let url,
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            !items.isEmpty
        else {
            return "query: none"
        }
        let parameters = items.map { item in
            if item.name == "q" { return "q=<private>" }
            return item.value.map { "\(item.name)=\($0)" } ?? item.name
        }
        return "query: \(parameters.joined(separator: ", "))"
    }

    private static func headerLines(_ headers: [String: String]) -> [String] {
        let sorted = headers.sorted { $0.key.lowercased() < $1.key.lowercased() }
        return ["headers:"] + sorted.map { name, value in
            "  \(name): \(redactedHeaders.contains(name.lowercased()) ? "<redacted>" : value)"
        }
    }

    private static func bodyLines(_ body: Data, mimeType: String?) -> [String] {
        guard !body.isEmpty else { return ["body: empty"] }
        let type = mimeType?.lowercased() ?? ""
        let text: String?
        if type.contains("json"), let pretty = prettyJSON(body) {
            text = pretty
        } else if type.isEmpty || type.hasPrefix("text/") || type.contains("json") || type.contains("xml") {
            text = String(data: body, encoding: .utf8)
        } else {
            text = nil
        }
        guard let text else {
            return ["body: \(body.count) bytes (\(mimeType ?? "unknown type")), not logged"]
        }
        let parts = chunks(text)
        return parts.enumerated().flatMap { index, part in
            ["body \(index + 1)/\(parts.count):", part]
        }
    }

    private static func prettyJSON(_ data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
            let pretty = try? JSONSerialization.data(withJSONObject: redactingEmails(object), options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed])
        else {
            return nil
        }
        return String(decoding: pretty, as: UTF8.self)
    }

    /// Reviewer email is never logged (ProductSpecification § 4.3): the value of every key that
    /// contains "email", at any depth, becomes `<redacted>`.
    private static func redactingEmails(_ object: Any) -> Any {
        if let dictionary = object as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dictionary {
                result[key] = key.lowercased().contains("email") ? "<redacted>" : redactingEmails(value)
            }
            return result
        }
        if let array = object as? [Any] {
            return array.map(redactingEmails)
        }
        return object
    }
}
#endif
