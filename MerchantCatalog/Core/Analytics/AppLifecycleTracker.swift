import Foundation

/// The app's scene phase, without SwiftUI. `MerchantCatalogApp` maps `ScenePhase` to it.
enum AppPhase: String, Sendable {
    case active
    case inactive
    case background
}

/// Turns scene-phase changes into lifecycle events and session boundaries (Analytics.md
/// § Lifecycle):
/// - the first `.active` starts a cold session unless an earlier event already did (D-36), and
///   sends no `app_foregrounded`;
/// - `.background` after `.active` sends `app_backgrounded` with the time in the foreground;
/// - `.active` after `.background` sends `app_foregrounded` with the time in the background,
///   preceded by a resume `session_started` when that time reached the session timeout.
///
/// `.inactive` and repeated phases send nothing. Durations are whole seconds, rounded down, and
/// never negative (D-35).
@MainActor
final class AppLifecycleTracker {
    private let analytics: any AnalyticsTracking
    private let sessions: SessionTracker
    private let now: () -> Date
    /// Set while the app is in the foreground (`.active`, including a passing `.inactive`).
    private var foregroundSince: Date?
    /// Set while the app is in the background after having been active.
    private var backgroundSince: Date?

    init(analytics: any AnalyticsTracking, sessions: SessionTracker, now: @escaping () -> Date = Date.init) {
        self.analytics = analytics
        self.sessions = sessions
        self.now = now
    }

    func handle(_ phase: AppPhase) {
        Log.lifecycle.info("scene phase \(phase.rawValue, privacy: .public)")
        switch phase {
        case .active: becameActive()
        case .background: enteredBackground()
        case .inactive: break
        }
    }

    private func becameActive() {
        guard foregroundSince == nil else { return }
        let date = now()

        if let backgroundSince {
            let backgroundDuration = Self.elapsed(from: backgroundSince, to: date)
            if sessions.isExpired(afterBackground: backgroundDuration) {
                startSession(kind: .resume, at: date)
            }
            analytics.track(.appForegrounded(backgroundDurationS: Int(backgroundDuration)))
            self.backgroundSince = nil
        } else if sessions.current == nil {
            startSession(kind: .cold, at: date)
        }
        foregroundSince = date
    }

    private func enteredBackground() {
        guard let foregroundSince else { return }
        let date = now()
        let foregroundDuration = Self.elapsed(from: foregroundSince, to: date)
        analytics.track(.appBackgrounded(foregroundDurationS: Int(foregroundDuration)))
        self.foregroundSince = nil
        backgroundSince = date
    }

    private func startSession(kind: LaunchKind, at date: Date) {
        analytics.track(sessions.startSession(kind: kind, at: date))
        Log.lifecycle.info("session started (\(kind.rawValue, privacy: .public))")
    }

    /// Seconds from `start` to `end`; 0 when the wall clock moved backwards.
    private static func elapsed(from start: Date, to end: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(start))
    }
}
