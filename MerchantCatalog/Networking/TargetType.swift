import Foundation

/// A Moya-style endpoint description: everything `URLSessionAPIClient` needs to build a request.
/// Endpoints are enums (`ProductsTarget`), so the set of requests the app can make is closed.
protocol TargetType: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var timeout: TimeInterval { get }
}

extension TargetType {
    var baseURL: URL { APIConfig.baseURL }
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }
    var timeout: TimeInterval { APIConfig.defaultTimeout }
}
