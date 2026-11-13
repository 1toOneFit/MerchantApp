import Foundation
import Testing
@testable import MerchantCatalog

struct LoggingAnalyticsProviderTests {
    @Test func eventMessageListsEnvelopeAndSortedProperties() {
        let envelope = AnalyticsEnvelope(
            event: .sessionStarted(isFirstSession: true, launchKind: .cold),
            timestamp: date("2026-11-13T10:00:00Z"),
            installationID: uuid(1),
            sessionID: uuid(2),
            sequence: 1
        )

        #expect(LoggingAnalyticsProvider.message(for: envelope) ==
            "event session_started #1 session 00000000-0000-0000-0000-000000000002 {is_first_session=true, launch_kind=cold}")
    }

    @Test func userPropertyMessageShowsOldAndNewValues() {
        let first = UserPropertyChange(name: "app_version", oldValue: nil, newValue: .string("1.0"))
        let second = UserPropertyChange(name: "build_number", oldValue: .string("1"), newValue: .string("2"))

        #expect(LoggingAnalyticsProvider.message(for: first) == "user property app_version: nil → 1.0")
        #expect(LoggingAnalyticsProvider.message(for: second) == "user property build_number: 1 → 2")
    }
}
