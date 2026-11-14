import Foundation
import Testing
@testable import MerchantCatalog

/// `experiment_exposed`: once per experiment per session, for both arms (Experiments.md § Eligibility
/// and exposure, D-74).
@MainActor
struct ExposureTrackerTests {
    private let store = IsolatedDefaults()
    private let clock = TestNow()
    private let sessionIDs = SequentialUUIDs()
    private let analytics = SpyAnalytics()
    private let sessions: SessionTracker
    private let lifecycle: AppLifecycleTracker
    private let tracker: ExposureTracker

    private static let treatment = ExperimentAssignment(variant: .treatment, source: .hashed)

    init() {
        sessions = SessionTracker(defaults: store.defaults, makeID: sessionIDs.next)
        lifecycle = AppLifecycleTracker(analytics: analytics, sessions: sessions, now: clock.now)
        tracker = ExposureTracker(analytics: analytics, sessions: sessions)
    }

    private var exposures: [AnalyticsEvent] {
        analytics.events.filter { $0.name == .experimentExposed }
    }

    @Test func experimentExposedProperties() {
        let event = AnalyticsEvent.experimentExposed(
            experiment: .productCardDensity,
            assignment: ExperimentAssignment(variant: .control, source: .override),
            surface: .searchGrid
        )

        #expect(event.name.rawValue == "experiment_exposed")
        #expect(event.properties == [
            "experiment_id": .string("product_card_density_v1"),
            "variant": .string("control"),
            "assignment_source": .string("override"),
            "surface": .string("search_grid"),
        ])
    }

    @Test func firstRenderSendsExposure() {
        lifecycle.handle(.active)

        tracker.cardRendered(.productCardDensity, assignment: Self.treatment, surface: .catalogGrid)

        #expect(exposures == [.experimentExposed(experiment: .productCardDensity, assignment: Self.treatment, surface: .catalogGrid)])
    }

    @Test func laterRendersInTheSessionAreSuppressed() {
        lifecycle.handle(.active)

        tracker.cardRendered(.productCardDensity, assignment: Self.treatment, surface: .catalogGrid)
        tracker.cardRendered(.productCardDensity, assignment: Self.treatment, surface: .catalogGrid)
        tracker.cardRendered(.productCardDensity, assignment: Self.treatment, surface: .searchGrid)

        #expect(exposures.count == 1)
    }

    @Test func bothArmsAreExposed() {
        lifecycle.handle(.active)
        let control = ExperimentAssignment(variant: .control, source: .hashed)

        tracker.cardRendered(.productCardDensity, assignment: control, surface: .catalogGrid)

        #expect(exposures == [.experimentExposed(experiment: .productCardDensity, assignment: control, surface: .catalogGrid)])
    }

    /// A return after the 30-minute timeout starts a new session, which is exposed again.
    @Test func newSessionExposesAgain() {
        lifecycle.handle(.active)
        tracker.cardRendered(.productCardDensity, assignment: Self.treatment, surface: .catalogGrid)
        lifecycle.handle(.background)
        clock.advance(by: SessionTracker.defaultTimeout)
        lifecycle.handle(.active)

        tracker.cardRendered(.productCardDensity, assignment: Self.treatment, surface: .searchGrid)

        #expect(sessions.current?.id == uuid(2))
        #expect(exposures == [
            .experimentExposed(experiment: .productCardDensity, assignment: Self.treatment, surface: .catalogGrid),
            .experimentExposed(experiment: .productCardDensity, assignment: Self.treatment, surface: .searchGrid),
        ])
    }

    /// The exposure can be the launch's first event: `AnalyticsService` starts the cold session for
    /// it, and later renders in that session are suppressed (D-74).
    @Test func exposureStartingTheSessionIsDeduplicated() {
        let provider = SpyAnalyticsProvider()
        let installation = InstallationIDProvider(defaults: store.defaults)
        let service = AnalyticsService(providers: [provider], installation: installation, sessions: sessions)
        let tracker = ExposureTracker(analytics: service, sessions: sessions)

        tracker.cardRendered(.productCardDensity, assignment: Self.treatment, surface: .catalogGrid)
        tracker.cardRendered(.productCardDensity, assignment: Self.treatment, surface: .catalogGrid)

        #expect(provider.envelopes.map(\.event.name) == [.sessionStarted, .experimentExposed])
    }
}
