import Foundation

/// One analytics session (Analytics.md § 2).
struct AnalyticsSession: Equatable, Sendable {
    let id: UUID
    let startedAt: Date
}

/// Owns the current session and its event sequence. Callers decide *when* a session starts
/// (`AnalyticsService` on the first event, `AppLifecycleTracker` on the first `.active` phase or
/// after the timeout); this type applies the rules:
/// - a return to the foreground after `timeout` or more in the background starts a new session;
/// - `sequence` is 1-based and restarts with every session;
/// - `is_first_session` is true only for the installation's first session, remembered in
///   `UserDefaults` across launches.
///
/// `@MainActor` like the rest of the analytics stack (D-33).
@MainActor
final class SessionTracker {
    static let defaultTimeout: TimeInterval = 30 * 60

    private static let hasStartedSessionKey = "analytics.has_started_session"

    private(set) var current: AnalyticsSession?

    private var lastSequence = 0
    private let defaults: UserDefaults
    private let timeout: TimeInterval
    private let makeID: () -> UUID

    init(
        defaults: UserDefaults,
        timeout: TimeInterval = SessionTracker.defaultTimeout,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.defaults = defaults
        self.timeout = timeout
        self.makeID = makeID
    }

    /// Starts a new session, restarts the sequence, and returns the `session_started` event for the
    /// caller to track.
    func startSession(kind: LaunchKind, at date: Date) -> AnalyticsEvent {
        let isFirstSession = !defaults.bool(forKey: Self.hasStartedSessionKey)
        defaults.set(true, forKey: Self.hasStartedSessionKey)
        current = AnalyticsSession(id: makeID(), startedAt: date)
        lastSequence = 0
        return .sessionStarted(isFirstSession: isFirstSession, launchKind: kind)
    }

    /// Whether returning to the foreground after `duration` seconds in the background starts a new
    /// session. Exactly the timeout counts as expired.
    func isExpired(afterBackground duration: TimeInterval) -> Bool {
        duration >= timeout
    }

    /// The next 1-based sequence number within the current session.
    func nextSequence() -> Int {
        lastSequence += 1
        return lastSequence
    }

    /// Ends the current session and forgets that this installation had one, so the next session
    /// reports `is_first_session = true` (D-34, DEBUG fresh-install reset).
    func resetForNewInstallation() {
        current = nil
        lastSequence = 0
        defaults.removeObject(forKey: Self.hasStartedSessionKey)
    }
}
