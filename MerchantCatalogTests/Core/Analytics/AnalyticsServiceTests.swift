import Foundation
import Testing
@testable import MerchantCatalog

@MainActor
struct AnalyticsServiceTests {
    private let store = IsolatedDefaults()
    private let clock = TestNow()
    private let installationIDs = SequentialUUIDs()
    private let sessionIDs = SequentialUUIDs()
    private let installation: InstallationIDProvider
    private let sessions: SessionTracker

    init() {
        installation = InstallationIDProvider(defaults: store.defaults, now: clock.now, makeID: installationIDs.next)
        sessions = SessionTracker(defaults: store.defaults, makeID: sessionIDs.next)
    }

    private func makeService(_ providers: [any AnalyticsProvider]) -> AnalyticsService {
        AnalyticsService(providers: providers, installation: installation, sessions: sessions, now: clock.now)
    }

    @Test func envelopeFieldsArePresentAndTyped() throws {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])
        clock.date = date("2026-11-13T10:15:30Z") + 0.25

        service.track(.appBackgrounded(foregroundDurationS: 12))

        let envelope = try #require(provider.envelopes.last)
        #expect(envelope.event == .appBackgrounded(foregroundDurationS: 12))
        #expect(envelope.fields == [
            "event": .string("app_backgrounded"),
            "timestamp": .string("2026-11-13T10:15:30.250Z"),
            "installation_id": .string("00000000-0000-0000-0000-000000000001"),
            "session_id": .string("00000000-0000-0000-0000-000000000001"),
            "sequence": .int(2),
        ])
    }

    @Test func firstEventStartsAColdSessionFirst() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])

        service.track(.appForegrounded(backgroundDurationS: 5))

        #expect(provider.envelopes.map(\.event) == [
            .sessionStarted(isFirstSession: true, launchKind: .cold),
            .appForegrounded(backgroundDurationS: 5),
        ])
        #expect(provider.envelopes.map(\.sequence) == [1, 2])
        #expect(provider.envelopes.map(\.sessionID) == [uuid(1), uuid(1)])
    }

    @Test func eventsInARunningSessionStartNoNewSession() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])
        service.track(sessions.startSession(kind: .cold, at: clock.date))

        service.track(.appBackgrounded(foregroundDurationS: 1))

        #expect(provider.envelopes.map(\.event.name) == [.sessionStarted, .appBackgrounded])
        #expect(provider.envelopes.map(\.sequence) == [1, 2])
    }

    @Test func sequenceRestartsInANewSession() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])
        service.track(.appBackgrounded(foregroundDurationS: 1))

        service.track(sessions.startSession(kind: .resume, at: clock.date))
        service.track(.appForegrounded(backgroundDurationS: 1_800))

        #expect(provider.envelopes.map(\.sequence) == [1, 2, 1, 2])
        #expect(provider.envelopes.map(\.sessionID) == [uuid(1), uuid(1), uuid(2), uuid(2)])
    }

    /// Adding a destination is a new provider passed to the service; `AnalyticsTracking` and the
    /// call site do not change.
    @Test func everyProviderReceivesEveryEvent() {
        let providers = [SpyAnalyticsProvider(), SpyAnalyticsProvider(), SpyAnalyticsProvider()]
        let service = makeService(providers)
        let tracking: any AnalyticsTracking = service

        tracking.track(.appBackgrounded(foregroundDurationS: 3))
        tracking.track(.appForegrounded(backgroundDurationS: 4))

        #expect(providers[0].envelopes.count == 3)
        #expect(providers[1].envelopes == providers[0].envelopes)
        #expect(providers[2].envelopes == providers[0].envelopes)
    }

    @Test func everyProviderReceivesUserPropertyChanges() {
        let providers = [SpyAnalyticsProvider(), SpyAnalyticsProvider()]
        let service = makeService(providers)

        service.setUserProperty(.appVersion("1.0"))

        let expected = [UserPropertyChange(name: "app_version", oldValue: nil, newValue: .string("1.0"))]
        #expect(providers[0].changes == expected)
        #expect(providers[1].changes == expected)
    }

    @Test func userPropertyEmitsOnlyWhenItsValueChanges() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])

        service.setUserProperty(.buildNumber("1"))
        service.setUserProperty(.buildNumber("1"))
        service.setUserProperty(.isDebugBuild(true))
        service.setUserProperty(.buildNumber("2"))
        service.setUserProperty(.isDebugBuild(true))

        #expect(provider.changes == [
            UserPropertyChange(name: "build_number", oldValue: nil, newValue: .string("1")),
            UserPropertyChange(name: "is_debug_build", oldValue: nil, newValue: .bool(true)),
            UserPropertyChange(name: "build_number", oldValue: .string("1"), newValue: .string("2")),
        ])
    }

    @Test func userPropertiesNeedNoSession() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])

        service.setUserProperty(.osVersion("26.0"))

        #expect(sessions.current == nil)
        #expect(provider.envelopes.isEmpty)
    }

    @Test(arguments: [
        (UserProperty.appVersion("1.0"), "app_version", AnalyticsValue.string("1.0")),
        (.buildNumber("7"), "build_number", .string("7")),
        (.osVersion("26.0"), "os_version", .string("26.0")),
        (.deviceModel("iPhone18,3"), "device_model", .string("iPhone18,3")),
        (.firstSeenDate(date("2026-11-14T03:30:00Z")), "first_seen_date", .string("2026-11-14")),
        (.firstSeenDate(date("2026-11-13T23:59:59Z")), "first_seen_date", .string("2026-11-13")),
        (.isDebugBuild(false), "is_debug_build", .bool(false)),
    ])
    func userPropertyNamesAndValues(property: UserProperty, name: String, value: AnalyticsValue) {
        #expect(property.name == name)
        #expect(property.value == value)
    }

    // MARK: - saved_product_revisited (D-64)

    private func viewed(_ id: Int, savedAt: Date?, source: ProductSource = .saved) -> AnalyticsEvent {
        .productDetailsViewed(productID: id, source: source, category: nil, availability: nil, hasDiscount: nil, imageCount: nil, savedAt: savedAt, contentOrigin: .snapshot)
    }

    @Test func revisitFollowsDetailsOfAProductSavedBeforeTheSession() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])

        service.track(viewed(7, savedAt: date("2026-11-10T11:00:00Z"), source: .catalog))

        #expect(provider.envelopes.map(\.event) == [
            .sessionStarted(isFirstSession: true, launchKind: .cold),
            viewed(7, savedAt: date("2026-11-10T11:00:00Z"), source: .catalog),
            .savedProductRevisited(productID: 7, source: .catalog, daysSinceSaved: 2),
        ])
        #expect(provider.envelopes.map(\.sequence) == [1, 2, 3])
    }

    @Test func noRevisitForAProductSavedThisSession() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])
        service.track(.appBackgrounded(foregroundDurationS: 1))
        clock.advance(by: 60)

        service.track(viewed(7, savedAt: clock.date - 30))

        #expect(provider.envelopes.last?.event.name == .productDetailsViewed)
    }

    @Test func noRevisitForAnUnsavedProduct() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])

        service.track(viewed(7, savedAt: nil))

        #expect(provider.envelopes.last?.event.name == .productDetailsViewed)
    }

    @Test func revisitOncePerProductPerSession() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])
        let savedAt = date("2026-11-12T10:00:00Z")

        service.track(viewed(7, savedAt: savedAt))
        service.track(viewed(7, savedAt: savedAt))
        service.track(viewed(8, savedAt: savedAt))

        let revisits = provider.envelopes.map(\.event).filter { $0.name == .savedProductRevisited }
        #expect(revisits == [
            .savedProductRevisited(productID: 7, source: .saved, daysSinceSaved: 1),
            .savedProductRevisited(productID: 8, source: .saved, daysSinceSaved: 1),
        ])
    }

    @Test func aNewSessionRevisitsAgain() {
        let provider = SpyAnalyticsProvider()
        let service = makeService([provider])
        let savedAt = date("2026-11-12T10:00:00Z")
        service.track(viewed(7, savedAt: savedAt))

        clock.advance(by: 3_600)
        service.track(sessions.startSession(kind: .resume, at: clock.date))
        service.track(viewed(7, savedAt: savedAt))

        let revisits = provider.envelopes.filter { $0.event.name == .savedProductRevisited }
        #expect(revisits.map(\.sessionID) == [uuid(1), uuid(2)])
    }
}
