import Foundation

/// A screen that renders the experiment's card (Experiments.md § Eligibility and exposure).
enum ExposureSurface: String, Sendable {
    case catalogGrid = "catalog_grid"
    case searchGrid = "search_grid"
}

/// Sends `experiment_exposed` when the first experiment card renders in a session, for both arms;
/// later renders in the same session are suppressed and logged at debug level.
///
/// Keyed by session id + experiment. The session id is read after tracking: when the exposure is
/// the launch's first event, `AnalyticsService` starts the cold session for it, and that session is
/// the one recorded (D-74).
///
/// `@MainActor` like the analytics stack (D-33).
@MainActor
final class ExposureTracker {
    private let analytics: any AnalyticsTracking
    private let sessions: SessionTracker
    /// The session each experiment was last exposed in.
    private var exposedSessions: [Experiment: UUID] = [:]

    init(analytics: any AnalyticsTracking, sessions: SessionTracker) {
        self.analytics = analytics
        self.sessions = sessions
    }

    /// A card of `experiment` rendered on `surface` with `assignment`.
    func cardRendered(_ experiment: Experiment, assignment: ExperimentAssignment, surface: ExposureSurface) {
        if let session = sessions.current?.id, exposedSessions[experiment] == session {
            Log.experiment.debug("\(experiment.rawValue, privacy: .public) exposure on \(surface.rawValue, privacy: .public) suppressed: already exposed in this session")
            return
        }
        analytics.track(.experimentExposed(experiment: experiment, assignment: assignment, surface: surface))
        exposedSessions[experiment] = sessions.current?.id
    }
}
