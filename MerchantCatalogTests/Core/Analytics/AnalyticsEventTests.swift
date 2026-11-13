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

    /// `experiment_assignments` (S6): keys sorted, so logs and Diagnostics read the same each time.
    @Test func stringMapDescriptionIsSorted() {
        let value = AnalyticsValue.stringMap(["b_experiment": "treatment", "a_experiment": "control"])

        #expect(value.description == "{a_experiment: control, b_experiment: treatment}")
    }

    @Test func experimentAssignmentsProperty() {
        let property = UserProperty.experimentAssignments(["product_card_density_v1": "treatment"])

        #expect(property.name == "experiment_assignments")
        #expect(property.value == .stringMap(["product_card_density_v1": "treatment"]))
    }
}
