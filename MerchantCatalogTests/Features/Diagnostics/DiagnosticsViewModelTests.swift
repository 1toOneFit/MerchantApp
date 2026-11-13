#if DEBUG
import Foundation
import Testing
@testable import MerchantCatalog

@MainActor
struct DiagnosticsViewModelTests {
    private let store = IsolatedDefaults()
    private let clock = TestNow()
    private let installationIDs = SequentialUUIDs()
    private let sessionIDs = SequentialUUIDs()
    private let eventLog = InMemoryAnalyticsProvider()
    private let installation: InstallationIDProvider
    private let sessions: SessionTracker
    private let analytics: AnalyticsService
    private let requestDelay = RequestDelay()
    private let slowNetwork: SlowNetworkSetting

    init() {
        installation = InstallationIDProvider(defaults: store.defaults, now: clock.now, makeID: installationIDs.next)
        sessions = SessionTracker(defaults: store.defaults, makeID: sessionIDs.next)
        analytics = AnalyticsService(providers: [eventLog], installation: installation, sessions: sessions, now: clock.now)
        slowNetwork = SlowNetworkSetting(defaults: store.defaults, requestDelay: requestDelay)
    }

    private func makeViewModel(
        logs: Result<[LogEntry], FakeLogReaderError> = .success([])
    ) -> DiagnosticsViewModel {
        DiagnosticsViewModel(
            eventLog: eventLog,
            installation: installation,
            sessions: sessions,
            analytics: analytics,
            logReader: FakeLogReader(result: logs),
            slowNetwork: slowNetwork,
            now: clock.now
        )
    }

    @Test func slowNetworkToggleForwardsToSetting() {
        let viewModel = makeViewModel()
        #expect(!viewModel.isSlowNetworkEnabled)

        viewModel.isSlowNetworkEnabled = true

        #expect(slowNetwork.isEnabled)
        #expect(requestDelay.value == SlowNetworkSetting.delay)
    }

    @Test func slowNetworkToggleStartsFromTheSetting() {
        slowNetwork.isEnabled = true

        #expect(makeViewModel().isSlowNetworkEnabled)
    }

    @Test func eventsAreNewestFirstWithSortedProperties() throws {
        let viewModel = makeViewModel()

        analytics.track(.appBackgrounded(foregroundDurationS: 12))

        #expect(viewModel.events.map(\.name) == ["app_backgrounded", "session_started"])
        #expect(viewModel.events.map(\.sequence) == [2, 1])
        let sessionStarted = try #require(viewModel.events.last)
        #expect(sessionStarted.id == "\(uuid(1).uuidString)#1")
        #expect(sessionStarted.timestamp == date("2026-11-13T10:00:00Z"))
        #expect(sessionStarted.properties == [
            DiagnosticsProperty(name: "is_first_session", value: "true"),
            DiagnosticsProperty(name: "launch_kind", value: "cold"),
        ])
    }

    @Test func currentSessionIsTheLatestEventsSession() {
        let viewModel = makeViewModel()
        #expect(viewModel.currentSessionID == nil)

        analytics.track(.appBackgrounded(foregroundDurationS: 1))

        #expect(viewModel.currentSessionID == uuid(1).uuidString)
    }

    @Test func userPropertiesAreSortedRows() {
        let viewModel = makeViewModel()

        analytics.setUserProperty(.osVersion("26.0"))
        analytics.setUserProperty(.appVersion("1.0"))
        analytics.setUserProperty(.isDebugBuild(true))

        #expect(viewModel.userProperties == [
            DiagnosticsProperty(name: "app_version", value: "1.0"),
            DiagnosticsProperty(name: "is_debug_build", value: "true"),
            DiagnosticsProperty(name: "os_version", value: "26.0"),
        ])
    }

    @Test func loadLogsShowsTheEntries() async {
        let entry = LogEntry(
            id: uuid(9),
            date: date("2026-11-13T10:00:00Z"),
            category: "lifecycle",
            level: "info",
            message: "App launched"
        )
        let viewModel = makeViewModel(logs: .success([entry]))
        #expect(viewModel.logs == .idle)

        await viewModel.loadLogs()

        #expect(viewModel.logs == .loaded([entry]))
    }

    @Test func loadLogsFailureShowsTheMessage() async {
        let viewModel = makeViewModel(logs: .failure(FakeLogReaderError()))

        await viewModel.loadLogs()

        #expect(viewModel.logs == .failed("log store unavailable"))
    }

    /// D-34: the reset behaves like a reinstall.
    @Test func resetStartsAFreshInstallationSession() throws {
        let viewModel = makeViewModel()
        analytics.setUserProperty(.firstSeenDate(installation.firstSeenDate))
        analytics.track(.appBackgrounded(foregroundDurationS: 1))
        #expect(viewModel.installationID == uuid(1).uuidString)
        clock.advance(by: 86_400)

        viewModel.resetInstallationID()

        #expect(viewModel.installationID == uuid(2).uuidString)
        let latest = try #require(eventLog.events.last)
        #expect(latest.event == .sessionStarted(isFirstSession: true, launchKind: .cold))
        #expect(latest.sequence == 1)
        #expect(latest.sessionID == uuid(2))
        #expect(latest.installationID == uuid(2))
        #expect(eventLog.userProperties["first_seen_date"] == .string("2026-11-14"))
        #expect(viewModel.currentSessionID == uuid(2).uuidString)
    }
}
#endif
