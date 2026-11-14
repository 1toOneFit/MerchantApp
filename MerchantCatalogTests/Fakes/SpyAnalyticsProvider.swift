@testable import MerchantCatalog

/// Records everything `AnalyticsService` delivers to a provider.
@MainActor
final class SpyAnalyticsProvider: AnalyticsProvider {
    private(set) var envelopes: [AnalyticsEnvelope] = []
    private(set) var changes: [UserPropertyChange] = []

    func send(_ envelope: AnalyticsEnvelope) {
        envelopes.append(envelope)
    }

    func userPropertyDidChange(_ change: UserPropertyChange) {
        changes.append(change)
    }
}
