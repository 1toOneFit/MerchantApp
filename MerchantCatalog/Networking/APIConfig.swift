import Foundation

/// Static settings for the DummyJSON Products API (Networking.md § 1–2).
enum APIConfig {
    /// Every endpoint's default base URL.
    static let baseURL: URL = {
        guard let url = URL(string: "https://dummyjson.com") else {
            preconditionFailure("APIConfig.baseURL is not a valid URL")
        }
        return url
    }()

    /// Seconds before a request fails with `AppError.timeout`.
    static let defaultTimeout: TimeInterval = 15
}
