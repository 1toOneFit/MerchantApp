import Foundation
@testable import MerchantCatalog

/// Records requested targets and answers with `responseJSON` decoded as the requested type, or
/// throws `error`. Main-actor isolated so tests can set and read it without locks; the protocol's
/// async requirement lets an isolated method witness it.
@MainActor
final class FakeAPIClient: APIClientType {
    struct Request: Equatable {
        let path: String
        let queryItems: [URLQueryItem]
    }

    private(set) var requests: [Request] = []
    var responseJSON = Data()
    var error: (any Error)?

    func request<Response: Decodable & Sendable>(_ target: some TargetType) async throws -> Response {
        requests.append(Request(path: target.path, queryItems: target.queryItems))
        if let error { throw error }
        return try JSONDecoder().decode(Response.self, from: responseJSON)
    }
}
