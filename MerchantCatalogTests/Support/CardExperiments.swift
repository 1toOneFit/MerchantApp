@testable import MerchantCatalog

/// A `CardExperiment` for catalog suites that don't look at the experiment: hashed `variant`, with
/// exposures going to a spy of their own, so the suite's analytics stay as they were before S6.
@MainActor
func unobservedCardExperiment(_ variant: ExperimentVariant = .control) -> CardExperiment {
    // `ExposureTracker` only reads the current session, so the defaults are never written.
    let sessions = SessionTracker(defaults: IsolatedDefaults().defaults)
    return CardExperiment(
        assignment: ExperimentAssignment(variant: variant, source: .hashed),
        exposure: ExposureTracker(analytics: SpyAnalytics(), sessions: sessions)
    )
}
