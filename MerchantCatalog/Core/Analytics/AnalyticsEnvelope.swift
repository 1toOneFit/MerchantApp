import Foundation

/// An event plus the envelope `AnalyticsService` attaches to it (Analytics.md § 2).
struct AnalyticsEnvelope: Equatable, Sendable {
    let event: AnalyticsEvent
    let timestamp: Date
    let installationID: UUID
    let sessionID: UUID
    /// 1-based order within the session.
    let sequence: Int

    /// The envelope fields as a vendor would receive them; the event's own properties stay in
    /// `event.properties`. `timestamp` is ISO 8601 in UTC with milliseconds.
    var fields: [String: AnalyticsValue] {
        [
            "event": .string(event.name.rawValue),
            "timestamp": .string(timestamp.formatted(Self.timestampStyle)),
            "installation_id": .string(installationID.uuidString),
            "session_id": .string(sessionID.uuidString),
            "sequence": .int(sequence),
        ]
    }

    private static let timestampStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
}
