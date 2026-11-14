#if DEBUG
import Foundation

/// DEBUG-only extended network logging (D-80, Architecture § 10).
///
/// - API requests: a framed REQUEST box when the request starts (method and URL, query parameters,
///   headers set by the app, timeout, body) and a framed RESPONSE box when it ends (status, time,
///   type, size, headers, body). `URLSession` adds its own default headers, such as `User-Agent`,
///   only when sending, so they don't appear.
/// - Image requests: one line when they end (`compactLine`), so scrolling stays readable.
/// - Bodies: JSON pretty-printed with sorted keys; text as is; binary only by size and type.
/// - Privacy: the search term stays `q=<private>` (D-18); credential headers and every JSON value
///   under a key containing "email" (reviewer emails) are `<redacted>`.
/// - Size: the unified log cuts a message at about 1 KB (measured 2026-11-14 on macOS with
///   `log show` and `log stream`: longer messages kept 1,005 of the payload's characters). A box is
///   therefore split at line breaks into messages of at most `maxMessageBytes`; every line starts
///   with the frame, so consecutive messages read as one box.
enum NetworkLogFormatter {
    /// The largest log message, in UTF-8 bytes; below the measured ~1 KB cut.
    static let maxMessageBytes = 800

    private static let closingLine = "└" + String(repeating: "─", count: 40)
    private static let redactedHeaders: Set<String> = ["authorization", "proxy-authorization", "cookie", "set-cookie", "x-api-key"]

    static func requestBox(_ request: URLRequest, id: String) -> [String] {
        var lines = [
            openingLine("→ REQUEST [\(id)]"),
            "│ \(request.httpMethod ?? "GET") \(request.url.map(NetworkLogger.sanitizedURL) ?? "nil")",
            "│ Query    \(query(of: request.url))",
        ]
        let headers = request.allHTTPHeaderFields ?? [:]
        lines += headers.isEmpty
            ? ["│ Headers  none set by the app (URLSession adds its defaults when sending)"]
            : headerLines(headers)
        lines.append("│ Timeout  \(String(format: "%g", request.timeoutInterval)) s")
        if let body = request.httpBody {
            lines += bodyLines(body, mimeType: request.value(forHTTPHeaderField: "Content-Type"))
        } else {
            lines.append("│ Body     none")
        }
        lines.append(closingLine)
        return messages(lines)
    }

    static func responseBox(_ response: HTTPURLResponse, body: Data, id: String, latency: Duration) -> [String] {
        var lines = [
            openingLine("← RESPONSE [\(id)] \(response.statusCode) · \(latency.wholeMilliseconds) ms"),
            "│ \(response.mimeType ?? "unknown type") · \(body.count) bytes",
        ]
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            headers["\(key)"] = "\(value)"
        }
        lines += headers.isEmpty ? ["│ Headers  none"] : headerLines(headers)
        lines += bodyLines(body, mimeType: response.mimeType)
        lines.append(closingLine)
        return messages(lines)
    }

    /// The closing box of a request that ended without a response (cancelled, failed) or whose
    /// response couldn't be used (decoding failed).
    static func endBox(id: String, outcome: String) -> [String] {
        messages([openingLine("← RESPONSE [\(id)] \(outcome)"), closingLine])
    }

    /// An image request in one line, written when it ends.
    static func compactLine(method: String, url: URL, id: String, outcome: String) -> String {
        "[\(id)] \(method) \(NetworkLogger.sanitizedURL(url)) → \(outcome)"
    }

    /// `text` split into chunks of at most `maxBytes` UTF-8 bytes, never inside a character. A chunk
    /// ends after its last line break when one fits; `chunks(text).joined() == text`.
    static func chunks(_ text: String, maxBytes: Int) -> [String] {
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

    // MARK: - Lines

    private static func openingLine(_ title: String) -> String {
        "┌──── \(title) ────"
    }

    /// The box's lines grouped into messages of whole lines (each line already fits).
    private static func messages(_ lines: [String]) -> [String] {
        chunks(lines.joined(separator: "\n"), maxBytes: maxMessageBytes).map { chunk in
            chunk.hasSuffix("\n") ? String(chunk.dropLast()) : chunk
        }
    }

    private static func query(of url: URL?) -> String {
        guard
            let url,
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            !items.isEmpty
        else {
            return "none"
        }
        return items
            .map { item in
                if item.name == "q" { return "q=<private>" }
                return item.value.map { "\(item.name)=\($0)" } ?? item.name
            }
            .joined(separator: ", ")
    }

    private static func headerLines(_ headers: [String: String]) -> [String] {
        let sorted = headers.sorted { $0.key.lowercased() < $1.key.lowercased() }
        return ["│ Headers"] + sorted.flatMap { name, value in
            framed("  \(name): \(redactedHeaders.contains(name.lowercased()) ? "<redacted>" : value)")
        }
    }

    private static func bodyLines(_ body: Data, mimeType: String?) -> [String] {
        guard !body.isEmpty else { return ["│ Body     empty"] }
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
            return ["│ Body     \(body.count) bytes (\(mimeType ?? "unknown type")), not logged"]
        }
        return ["│ Body"] + text.split(separator: "\n", omittingEmptySubsequences: false).flatMap { framed(String($0)) }
    }

    /// `content` behind the frame, wrapped into several framed lines if it wouldn't fit in one
    /// message, so every line of a box starts with the frame.
    private static func framed(_ content: String) -> [String] {
        chunks(content, maxBytes: maxMessageBytes - 8).map { "│ \($0)" }.ifEmpty(["│ "])
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

private extension Array {
    func ifEmpty(_ replacement: [Element]) -> [Element] {
        isEmpty ? replacement : self
    }
}
#endif
