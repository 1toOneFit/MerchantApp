@testable import MerchantCatalog

/// Records what a caller tracks through `AnalyticsTracking`, without envelopes or providers.
@MainActor
final class SpyAnalytics: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []
    private(set) var userProperties: [UserProperty] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func setUserProperty(_ property: UserProperty) {
        userProperties.append(property)
    }
}
