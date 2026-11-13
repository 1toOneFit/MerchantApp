/// Every failure the app shows or tracks. `URLSessionAPIClient` maps transport errors, HTTP
/// statuses and decoding errors to these cases (Networking.md § 2, D-43); cancellation is never an
/// `AppError`.
enum AppError: Error, Equatable, Sendable {
    /// No connection (`notConnectedToInternet`, `networkConnectionLost`, `dataNotAllowed`).
    case offline
    /// The request exceeded its timeout.
    case timeout
    /// HTTP 404.
    case notFound
    /// HTTP 429.
    case rateLimited
    /// Any other non-2xx status.
    case server(status: Int)
    /// A 2xx body that didn't decode.
    case decoding
    /// Anything else (other `URLError` codes, a non-HTTP response).
    case unknown

    /// The HTTP status behind the error, for the `http_status` analytics property.
    var httpStatus: Int? {
        switch self {
        case .notFound: 404
        case .rateLimited: 429
        case .server(let status): status
        case .offline, .timeout, .decoding, .unknown: nil
        }
    }

    /// A specific, actionable message (ProductSpecification § 4.5).
    var userMessage: String {
        switch self {
        case .offline: "You're offline. Check your connection and try again."
        case .timeout: "This is taking too long. Try again."
        case .notFound: "This product is no longer available."
        case .rateLimited: "Too many requests. Try again in a moment."
        case .server: "Something went wrong on our side. Try again later."
        case .decoding: "We received unexpected data. Try again later."
        case .unknown: "Something went wrong. Try again."
        }
    }
}
