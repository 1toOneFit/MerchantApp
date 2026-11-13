/// A destination for analytics: receives every enriched event and every user-property change from
/// `AnalyticsService`.
///
/// Adding or replacing a vendor (for example Amplitude or Firebase) means writing another
/// conforming type and passing it to `AnalyticsService` in `AppContext`; `AnalyticsTracking`,
/// events and call sites don't change. A vendor provider that does real work hands it to the SDK's
/// own queue instead of doing it on the main actor.
@MainActor
protocol AnalyticsProvider {
    func send(_ envelope: AnalyticsEnvelope)
    func userPropertyDidChange(_ change: UserPropertyChange)
}
