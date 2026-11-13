import Foundation
import Testing
@testable import MerchantCatalog

@MainActor
struct AppLifecycleTrackerTests {
    private let store = IsolatedDefaults()
    private let clock = TestNow()
    private let sessionIDs = SequentialUUIDs()
    private let analytics = SpyAnalytics()
    private let sessions: SessionTracker
    private let tracker: AppLifecycleTracker

    init() {
        sessions = SessionTracker(defaults: store.defaults, makeID: sessionIDs.next)
        tracker = AppLifecycleTracker(analytics: analytics, sessions: sessions, now: clock.now)
    }

    @Test func coldLaunchStartsASessionWithoutForegrounded() {
        tracker.handle(.inactive)
        tracker.handle(.active)

        #expect(analytics.events == [.sessionStarted(isFirstSession: true, launchKind: .cold)])
        #expect(sessions.current?.id == uuid(1))
    }

    @Test func backgroundSendsTheForegroundDuration() {
        tracker.handle(.active)
        clock.advance(by: 95.7)

        tracker.handle(.inactive)
        tracker.handle(.background)

        #expect(analytics.events.last == .appBackgrounded(foregroundDurationS: 95))
    }

    @Test func resumeUnderTheTimeoutKeepsTheSession() {
        tracker.handle(.active)
        tracker.handle(.background)
        clock.advance(by: 29 * 60)

        tracker.handle(.inactive)
        tracker.handle(.active)

        #expect(analytics.events.map(\.name) == [.sessionStarted, .appBackgrounded, .appForegrounded])
        #expect(analytics.events.last == .appForegrounded(backgroundDurationS: 1_740))
        #expect(sessions.current?.id == uuid(1))
    }

    @Test func resumeAtTheTimeoutStartsANewSessionFirst() {
        tracker.handle(.active)
        tracker.handle(.background)
        clock.advance(by: 30 * 60)

        tracker.handle(.active)

        #expect(analytics.events.suffix(2) == [
            .sessionStarted(isFirstSession: false, launchKind: .resume),
            .appForegrounded(backgroundDurationS: 1_800),
        ])
        #expect(sessions.current == AnalyticsSession(id: uuid(2), startedAt: clock.date))
    }

    @Test func foregroundDurationRestartsAfterEachResume() {
        tracker.handle(.active)
        clock.advance(by: 10)
        tracker.handle(.background)
        clock.advance(by: 20)
        tracker.handle(.active)
        clock.advance(by: 30)

        tracker.handle(.background)

        #expect(analytics.events.last == .appBackgrounded(foregroundDurationS: 30))
    }

    /// `onChange(initial: true)` can repeat a phase, and Control Center or the app switcher give
    /// `.active → .inactive → .active` without leaving the app.
    @Test func repeatedAndInactivePhasesSendNothing() {
        tracker.handle(.active)
        tracker.handle(.active)
        tracker.handle(.inactive)
        tracker.handle(.active)
        tracker.handle(.background)
        tracker.handle(.background)

        #expect(analytics.events.map(\.name) == [.sessionStarted, .appBackgrounded])
    }

    /// A prewarmed or background launch reports `.background` before the user ever sees the app.
    @Test func backgroundBeforeTheFirstActiveIsIgnored() {
        tracker.handle(.background)
        clock.advance(by: 3_600)

        tracker.handle(.active)

        #expect(analytics.events == [.sessionStarted(isFirstSession: true, launchKind: .cold)])
    }

    /// From S2 on a view can track before the scene reports `.active`; `AnalyticsService` then
    /// starts the cold session, and the first `.active` must not start another.
    @Test func firstActiveAfterAnEarlyEventDoesNotStartASecondSession() {
        _ = sessions.startSession(kind: .cold, at: clock.date)

        tracker.handle(.active)

        #expect(analytics.events == [])
        #expect(sessions.current?.id == uuid(1))
    }

    @Test func clockMovingBackwardsGivesZeroDurations() {
        tracker.handle(.active)
        clock.advance(by: -120)
        tracker.handle(.background)
        clock.advance(by: -7_200)

        tracker.handle(.active)

        #expect(analytics.events.suffix(2) == [
            .appBackgrounded(foregroundDurationS: 0),
            .appForegrounded(backgroundDurationS: 0),
        ])
        #expect(sessions.current?.id == uuid(1))
    }
}
