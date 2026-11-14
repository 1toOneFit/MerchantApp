import Foundation
import Testing
@testable import MerchantCatalog

@MainActor
struct SessionTrackerTests {
    private let store = IsolatedDefaults()
    private let ids = SequentialUUIDs()
    private let start = date("2026-11-13T10:00:00Z")

    private func makeTracker() -> SessionTracker {
        SessionTracker(defaults: store.defaults, makeID: ids.next)
    }

    @Test func noSessionBeforeStart() {
        #expect(makeTracker().current == nil)
    }

    @Test func firstStartIsTheFirstSession() {
        let tracker = makeTracker()

        let event = tracker.startSession(kind: .cold, at: start)

        #expect(event == .sessionStarted(isFirstSession: true, launchKind: .cold))
        #expect(tracker.current == AnalyticsSession(id: uuid(1), startedAt: start))
    }

    @Test func laterStartsAreNotFirstAcrossInstances() {
        _ = makeTracker().startSession(kind: .cold, at: start)
        let relaunched = makeTracker()

        let cold = relaunched.startSession(kind: .cold, at: start + 60)
        let resumed = relaunched.startSession(kind: .resume, at: start + 3_600)

        #expect(cold == .sessionStarted(isFirstSession: false, launchKind: .cold))
        #expect(resumed == .sessionStarted(isFirstSession: false, launchKind: .resume))
        #expect(relaunched.current == AnalyticsSession(id: uuid(3), startedAt: start + 3_600))
    }

    @Test func sequenceIncrementsAndRestartsPerSession() {
        let tracker = makeTracker()
        _ = tracker.startSession(kind: .cold, at: start)
        let firstSession = (1...3).map { _ in tracker.nextSequence() }

        _ = tracker.startSession(kind: .resume, at: start + 3_600)
        let secondSession = (1...2).map { _ in tracker.nextSequence() }

        #expect(firstSession == [1, 2, 3])
        #expect(secondSession == [1, 2])
    }

    @Test(arguments: [
        (0.0, false),
        (1_799.0, false),
        (1_799.9, false),
        (1_800.0, true),
        (7_200.0, true),
    ])
    func thirtyMinuteRule(backgroundDuration: TimeInterval, expired: Bool) {
        #expect(makeTracker().isExpired(afterBackground: backgroundDuration) == expired)
    }

    @Test func resetForNewInstallationEndsTheSessionAndTheNextIsFirst() {
        let tracker = makeTracker()
        _ = tracker.startSession(kind: .cold, at: start)

        tracker.resetForNewInstallation()

        #expect(tracker.current == nil)
        #expect(tracker.startSession(kind: .cold, at: start + 60) == .sessionStarted(isFirstSession: true, launchKind: .cold))
    }
}
