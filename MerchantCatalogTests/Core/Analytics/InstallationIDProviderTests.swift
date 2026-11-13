import Foundation
import Testing
@testable import MerchantCatalog

@MainActor
struct InstallationIDProviderTests {
    private let store = IsolatedDefaults()
    private let clock = TestNow()
    private let ids = SequentialUUIDs()

    private func makeProvider() -> InstallationIDProvider {
        InstallationIDProvider(defaults: store.defaults, now: clock.now, makeID: ids.next)
    }

    @Test func createdOnceAndPersisted() {
        let first = makeProvider()
        let second = makeProvider()

        #expect(first.installationID == uuid(1))
        #expect(second.installationID == uuid(1))
        #expect(ids.count == 1)
    }

    @Test func firstSeenDateIsTheCreationTimeAndPersists() {
        let first = makeProvider()
        clock.advance(by: 86_400)
        let second = makeProvider()

        #expect(first.firstSeenDate == date("2026-11-13T10:00:00Z"))
        #expect(second.firstSeenDate == date("2026-11-13T10:00:00Z"))
    }

    @Test func resetProducesANewIDAndFirstSeenDate() {
        let provider = makeProvider()
        clock.advance(by: 3_600)

        provider.reset()

        #expect(provider.installationID == uuid(2))
        #expect(provider.firstSeenDate == date("2026-11-13T11:00:00Z"))
        let reloaded = makeProvider()
        #expect(reloaded.installationID == uuid(2))
        #expect(reloaded.firstSeenDate == date("2026-11-13T11:00:00Z"))
    }

    @Test func invalidStoredValueIsReplaced() {
        store.defaults.set("not-a-uuid", forKey: "analytics.installation_id")

        let provider = makeProvider()

        #expect(provider.installationID == uuid(1))
        #expect(store.defaults.string(forKey: "analytics.installation_id") == uuid(1).uuidString)
    }

    @Test func missingFirstSeenDateKeepsTheStoredID() {
        store.defaults.set(uuid(7).uuidString, forKey: "analytics.installation_id")

        let provider = makeProvider()

        #expect(provider.installationID == uuid(7))
        #expect(provider.firstSeenDate == date("2026-11-13T10:00:00Z"))
        #expect(makeProvider().firstSeenDate == date("2026-11-13T10:00:00Z"))
        #expect(ids.count == 0)
    }
}
