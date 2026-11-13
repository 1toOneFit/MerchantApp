/// What features and view models use to record analytics. They depend only on this protocol and
/// receive it through their initializers; `AppContext` registers `AnalyticsService` under it.
///
/// `@MainActor` and synchronous (D-33): every caller is main-actor UI code, and a synchronous call
/// keeps event order and sequence numbers deterministic.
@MainActor
protocol AnalyticsTracking {
    /// Records `event`. The implementation adds the envelope (timestamp, installation id, session
    /// id, sequence).
    func track(_ event: AnalyticsEvent)
    /// Sets a user property. Implementations forward it only when its value changed.
    func setUserProperty(_ property: UserProperty)
}
