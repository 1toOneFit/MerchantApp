/// Event names from `docs/Analytics.md`. Only events whose status there is **Active** exist here;
/// `TaxonomyDocumentationTests` keeps the two equal.
enum AnalyticsEventName: String, CaseIterable, Sendable {
    case sessionStarted = "session_started"
    case appForegrounded = "app_foregrounded"
    case appBackgrounded = "app_backgrounded"
}

/// How a session began: a cold launch, or a return to the foreground after the session timeout.
enum LaunchKind: String, Sendable {
    case cold
    case resume
}

/// A product-analytics event with its typed properties. Features create these and pass them to
/// `AnalyticsTracking.track(_:)`; `AnalyticsService` adds the envelope.
enum AnalyticsEvent: Equatable, Sendable {
    /// A new session began (Analytics.md § Lifecycle).
    case sessionStarted(isFirstSession: Bool, launchKind: LaunchKind)
    /// The app became active after being in the background.
    case appForegrounded(backgroundDurationS: Int)
    /// The user left the app.
    case appBackgrounded(foregroundDurationS: Int)

    var name: AnalyticsEventName {
        switch self {
        case .sessionStarted: .sessionStarted
        case .appForegrounded: .appForegrounded
        case .appBackgrounded: .appBackgrounded
        }
    }

    var properties: [String: AnalyticsValue] {
        switch self {
        case .sessionStarted(let isFirstSession, let launchKind):
            ["is_first_session": .bool(isFirstSession), "launch_kind": .string(launchKind.rawValue)]
        case .appForegrounded(let backgroundDurationS):
            ["background_duration_s": .int(backgroundDurationS)]
        case .appBackgrounded(let foregroundDurationS):
            ["foreground_duration_s": .int(foregroundDurationS)]
        }
    }
}
