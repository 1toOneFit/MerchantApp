#if DEBUG
import Foundation
import Testing
@testable import MerchantCatalog

@MainActor
struct InMemoryAnalyticsProviderTests {
    private func envelope(sequence: Int) -> AnalyticsEnvelope {
        AnalyticsEnvelope(
            event: .appBackgrounded(foregroundDurationS: sequence),
            timestamp: date("2026-11-13T10:00:00Z"),
            installationID: uuid(1),
            sessionID: uuid(1),
            sequence: sequence
        )
    }

    @Test func keepsEventsOldestFirst() {
        let provider = InMemoryAnalyticsProvider(capacity: 5)

        (1...3).forEach { provider.send(envelope(sequence: $0)) }

        #expect(provider.events.map(\.sequence) == [1, 2, 3])
    }

    @Test func dropsTheOldestEventsBeyondCapacity() {
        let provider = InMemoryAnalyticsProvider(capacity: 3)

        (1...5).forEach { provider.send(envelope(sequence: $0)) }

        #expect(provider.events.map(\.sequence) == [3, 4, 5])
    }

    @Test func keepsTheCurrentUserPropertyValues() {
        let provider = InMemoryAnalyticsProvider()

        provider.userPropertyDidChange(UserPropertyChange(name: "build_number", oldValue: nil, newValue: .string("1")))
        provider.userPropertyDidChange(UserPropertyChange(name: "is_debug_build", oldValue: nil, newValue: .bool(true)))
        provider.userPropertyDidChange(UserPropertyChange(name: "build_number", oldValue: .string("1"), newValue: .string("2")))

        #expect(provider.userProperties == ["build_number": .string("2"), "is_debug_build": .bool(true)])
    }
}
#endif
