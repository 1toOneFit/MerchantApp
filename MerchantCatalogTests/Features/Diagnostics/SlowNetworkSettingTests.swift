#if DEBUG
import Testing
@testable import MerchantCatalog

/// DEBUG slow network (D-42): a 2 s `delay` on every API request, persisted across launches.
@MainActor
struct SlowNetworkSettingTests {
    private let store = IsolatedDefaults()

    @Test func offByDefault() {
        let delay = RequestDelay()
        let setting = SlowNetworkSetting(defaults: store.defaults, requestDelay: delay)

        #expect(!setting.isEnabled)
        #expect(delay.value == nil)
    }

    @Test func enablingSetsDelayAndPersists() {
        let delay = RequestDelay()
        let setting = SlowNetworkSetting(defaults: store.defaults, requestDelay: delay)

        setting.isEnabled = true
        #expect(delay.value == .milliseconds(2000))
        #expect(store.defaults.bool(forKey: "diagnostics.slow_network"))

        setting.isEnabled = false
        #expect(delay.value == nil)
        #expect(!store.defaults.bool(forKey: "diagnostics.slow_network"))
    }

    @Test func persistedValueIsAppliedAtInit() {
        SlowNetworkSetting(defaults: store.defaults, requestDelay: RequestDelay()).isEnabled = true
        let delay = RequestDelay()

        let relaunched = SlowNetworkSetting(defaults: store.defaults, requestDelay: delay)

        #expect(relaunched.isEnabled)
        #expect(delay.value == .milliseconds(2000))
    }
}
#endif
