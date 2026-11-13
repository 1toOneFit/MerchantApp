import Testing
@testable import MerchantCatalog

struct AnalyticsEventTests {
    @Test(arguments: [
        (
            AnalyticsEvent.sessionStarted(isFirstSession: true, launchKind: .cold),
            "session_started",
            ["is_first_session": AnalyticsValue.bool(true), "launch_kind": .string("cold")]
        ),
        (
            AnalyticsEvent.sessionStarted(isFirstSession: false, launchKind: .resume),
            "session_started",
            ["is_first_session": .bool(false), "launch_kind": .string("resume")]
        ),
        (
            AnalyticsEvent.appForegrounded(backgroundDurationS: 42),
            "app_foregrounded",
            ["background_duration_s": .int(42)]
        ),
        (
            AnalyticsEvent.appBackgrounded(foregroundDurationS: 7),
            "app_backgrounded",
            ["foreground_duration_s": .int(7)]
        ),
    ])
    func namesAndProperties(event: AnalyticsEvent, name: String, properties: [String: AnalyticsValue]) {
        #expect(event.name.rawValue == name)
        #expect(event.properties == properties)
    }

    @Test(arguments: [
        (AnalyticsValue.string("cold"), "cold"),
        (.int(42), "42"),
        (.bool(true), "true"),
        (.double(9.99), "9.99"),
    ])
    func valueDescriptionIsThePlainValue(value: AnalyticsValue, text: String) {
        #expect(value.description == text)
    }
}
