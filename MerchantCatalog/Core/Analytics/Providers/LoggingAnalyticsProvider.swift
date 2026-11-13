import OSLog

/// Writes every event and user-property change to the `analytics` log category at debug level
/// (Architecture § 10). Visible in Console.app with debug messages included.
///
/// Messages are logged `.public`: analytics carries ids, enum values, counts and durations, never
/// free text or search terms (D-18).
@MainActor
final class LoggingAnalyticsProvider: AnalyticsProvider {
    private let logger: Logger

    init(logger: Logger = Log.analytics) {
        self.logger = logger
    }

    func send(_ envelope: AnalyticsEnvelope) {
        logger.debug("\(Self.message(for: envelope), privacy: .public)")
    }

    func userPropertyDidChange(_ change: UserPropertyChange) {
        logger.debug("\(Self.message(for: change), privacy: .public)")
    }

    /// `event session_started #1 session <uuid> {is_first_session=true, launch_kind=cold}`, with
    /// properties sorted by name.
    nonisolated static func message(for envelope: AnalyticsEnvelope) -> String {
        let properties = envelope.event.properties
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        let event = envelope.event.name.rawValue
        return "event \(event) #\(envelope.sequence) session \(envelope.sessionID.uuidString) {\(properties)}"
    }

    /// `user property app_version: nil → 1.0`.
    nonisolated static func message(for change: UserPropertyChange) -> String {
        let oldValue = change.oldValue?.description ?? "nil"
        return "user property \(change.name): \(oldValue) → \(change.newValue)"
    }
}
