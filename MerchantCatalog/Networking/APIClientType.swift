/// What repositories use to talk to the API. Only `URLSessionAPIClient` touches `URLSession`;
/// another transport (a recording client, a mock server) is a new conforming type registered in
/// `AppContext`, with no change to repositories or view models.
protocol APIClientType: Sendable {
    /// Sends `target`'s request and decodes a 2xx body as `Response`.
    ///
    /// - Throws: `AppError` for failures (Networking.md § 2), or `CancellationError` when the calling
    ///   task is cancelled. Callers treat cancellation as "no state change".
    func request<Response: Decodable & Sendable>(_ target: some TargetType) async throws -> Response
}
