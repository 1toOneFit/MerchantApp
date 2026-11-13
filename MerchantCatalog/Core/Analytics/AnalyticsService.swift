import Foundation

/// The app's `AnalyticsTracking` implementation: adds the envelope to every event and fans events
/// and user-property changes out to every registered `AnalyticsProvider`.
///
/// - The first event with no running session starts a cold session first, so every event carries a
///   session id and `session_started` is always sequence 1 (D-36).
/// - A user property reaches providers only when its value differs from the last one set in this
///   process.
///
/// `@MainActor` and synchronous (D-33).
@MainActor
final class AnalyticsService: AnalyticsTracking {
    private let providers: [any AnalyticsProvider]
    private let installation: InstallationIDProvider
    private let sessions: SessionTracker
    private let now: () -> Date
    private var userPropertyValues: [String: AnalyticsValue] = [:]

    init(
        providers: [any AnalyticsProvider],
        installation: InstallationIDProvider,
        sessions: SessionTracker,
        now: @escaping () -> Date = Date.init
    ) {
        self.providers = providers
        self.installation = installation
        self.sessions = sessions
        self.now = now
    }

    func track(_ event: AnalyticsEvent) {
        let timestamp = now()
        if sessions.current == nil {
            deliver(sessions.startSession(kind: .cold, at: timestamp), at: timestamp)
        }
        deliver(event, at: timestamp)
    }

    func setUserProperty(_ property: UserProperty) {
        let oldValue = userPropertyValues[property.name]
        let newValue = property.value
        guard oldValue != newValue else { return }
        userPropertyValues[property.name] = newValue

        let change = UserPropertyChange(name: property.name, oldValue: oldValue, newValue: newValue)
        for provider in providers {
            provider.userPropertyDidChange(change)
        }
    }

    private func deliver(_ event: AnalyticsEvent, at timestamp: Date) {
        guard let session = sessions.current else {
            assertionFailure("AnalyticsService: no session for \(event.name.rawValue)")
            return
        }
        let envelope = AnalyticsEnvelope(
            event: event,
            timestamp: timestamp,
            installationID: installation.installationID,
            sessionID: session.id,
            sequence: sessions.nextSequence()
        )
        for provider in providers {
            provider.send(envelope)
        }
    }
}
