#if DEBUG
import Foundation
import Observation

/// A name/value row: a user property, or one property of an event.
struct DiagnosticsProperty: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let value: String
}

/// One analytics event as the Diagnostics sheet lists it.
struct DiagnosticsEvent: Identifiable, Equatable {
    /// `<session id>#<sequence>`, unique across sessions and installation resets.
    let id: String
    let name: String
    let sequence: Int
    let timestamp: Date
    /// Sorted by name.
    let properties: [DiagnosticsProperty]
}

/// DEBUG Diagnostics: shows the in-memory event log, the current user properties and recent log
/// entries, resets the installation id, toggles the slow network, and overrides the card
/// experiment's variant (applied at the next launch, D-69).
@MainActor
@Observable
final class DiagnosticsViewModel {
    enum LogsState: Equatable {
        case idle
        case loaded([LogEntry])
        case failed(String)
    }

    private(set) var logs: LogsState = .idle
    /// Stored, not read through from the provider, so the sheet updates after a reset.
    private(set) var installationID: String
    /// Adds a 2 s server-side delay to every API request (D-42). Stored so the toggle redraws;
    /// forwarded to the setting, which persists it.
    var isSlowNetworkEnabled: Bool {
        didSet { slowNetwork.isEnabled = isSlowNetworkEnabled }
    }
    /// `product_card_density_v1` as this launch shows it.
    let cardAssignment: ExperimentAssignment
    /// The persisted override; `nil` is Auto. Stored so the picker redraws; forwarded to the
    /// service, which keeps it for the next launch.
    var cardOverride: ExperimentVariant? {
        didSet { overrides.setOverride(cardOverride, for: .productCardDensity) }
    }

    private let eventLog: InMemoryAnalyticsProvider
    private let installation: InstallationIDProvider
    private let sessions: SessionTracker
    private let analytics: any AnalyticsTracking
    private let logReader: any LogReading
    private let slowNetwork: SlowNetworkSetting
    private let overrides: any ExperimentOverrides
    private let now: () -> Date

    init(
        eventLog: InMemoryAnalyticsProvider,
        installation: InstallationIDProvider,
        sessions: SessionTracker,
        analytics: any AnalyticsTracking,
        logReader: any LogReading,
        slowNetwork: SlowNetworkSetting,
        experiments: any ExperimentService,
        overrides: any ExperimentOverrides,
        now: @escaping () -> Date = Date.init
    ) {
        self.eventLog = eventLog
        self.installation = installation
        self.sessions = sessions
        self.analytics = analytics
        self.logReader = logReader
        self.slowNetwork = slowNetwork
        self.overrides = overrides
        self.now = now
        installationID = installation.installationID.uuidString
        isSlowNetworkEnabled = slowNetwork.isEnabled
        cardAssignment = experiments.assignment(for: .productCardDensity)
        cardOverride = overrides.override(for: .productCardDensity)
    }

    /// Newest first.
    var events: [DiagnosticsEvent] {
        eventLog.events.reversed().map { envelope in
            DiagnosticsEvent(
                id: "\(envelope.sessionID.uuidString)#\(envelope.sequence)",
                name: envelope.event.name.rawValue,
                sequence: envelope.sequence,
                timestamp: envelope.timestamp,
                properties: Self.rows(envelope.event.properties)
            )
        }
    }

    /// The session of the latest event: every session starts with a `session_started` event, and
    /// the event log is observable while `SessionTracker` is not.
    var currentSessionID: String? {
        eventLog.events.last?.sessionID.uuidString
    }

    /// Sorted by name.
    var userProperties: [DiagnosticsProperty] {
        Self.rows(eventLog.userProperties)
    }

    func loadLogs() async {
        do {
            logs = .loaded(try await logReader.recentEntries())
        } catch {
            logs = .failed(error.localizedDescription)
        }
    }

    /// Simulates a reinstall (D-34): a new installation id and first-seen date, and a new first
    /// session that starts at once. Stored experiment assignments are cleared, so the next launch
    /// buckets the new id; the override stays (D-72).
    func resetInstallationID() {
        installation.reset()
        overrides.clearStoredAssignments()
        sessions.resetForNewInstallation()
        analytics.track(sessions.startSession(kind: .cold, at: now()))
        analytics.setUserProperty(.firstSeenDate(installation.firstSeenDate))
        installationID = installation.installationID.uuidString
        Log.analytics.info("installation id reset")
    }

    private static func rows(_ values: [String: AnalyticsValue]) -> [DiagnosticsProperty] {
        values
            .map { DiagnosticsProperty(name: $0.key, value: $0.value.description) }
            .sorted { $0.name < $1.name }
    }
}
#endif
