#if DEBUG
/// Builds the DEBUG Diagnostics screen from the container. `resolveDependencies(from:)` is the
/// registration guard that `AppContextRegistrationTests` checks.
@MainActor
enum DiagnosticsConfigurator {
    struct Dependencies {
        let eventLog: InMemoryAnalyticsProvider
        let installation: InstallationIDProvider
        let sessions: SessionTracker
        let analytics: any AnalyticsTracking
        let logReader: any LogReading
        let slowNetwork: SlowNetworkSetting
        let experiments: any ExperimentService
        let overrides: any ExperimentOverrides
    }

    static func resolveDependencies(from container: any ServiceContainerType) -> Dependencies? {
        guard
            let eventLog: InMemoryAnalyticsProvider = container.resolve(),
            let installation: InstallationIDProvider = container.resolve(),
            let sessions: SessionTracker = container.resolve(),
            let analytics: any AnalyticsTracking = container.resolve(),
            let logReader: any LogReading = container.resolve(),
            let slowNetwork: SlowNetworkSetting = container.resolve(),
            let experiments: any ExperimentService = container.resolve(),
            let overrides: any ExperimentOverrides = container.resolve()
        else {
            return nil
        }
        return Dependencies(
            eventLog: eventLog,
            installation: installation,
            sessions: sessions,
            analytics: analytics,
            logReader: logReader,
            slowNetwork: slowNetwork,
            experiments: experiments,
            overrides: overrides
        )
    }

    static func make(from container: any ServiceContainerType) -> DiagnosticsView {
        guard let dependencies = resolveDependencies(from: container) else {
            preconditionFailure("DiagnosticsConfigurator: a service is not registered; see AppContextRegistrationTests")
        }
        let viewModel = DiagnosticsViewModel(
            eventLog: dependencies.eventLog,
            installation: dependencies.installation,
            sessions: dependencies.sessions,
            analytics: dependencies.analytics,
            logReader: dependencies.logReader,
            slowNetwork: dependencies.slowNetwork,
            experiments: dependencies.experiments,
            overrides: dependencies.overrides
        )
        return DiagnosticsView(viewModel: viewModel)
    }
}
#endif
