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
    }

    static func resolveDependencies(from container: any ServiceContainerType) -> Dependencies? {
        guard
            let eventLog: InMemoryAnalyticsProvider = container.resolve(),
            let installation: InstallationIDProvider = container.resolve(),
            let sessions: SessionTracker = container.resolve(),
            let analytics: any AnalyticsTracking = container.resolve(),
            let logReader: any LogReading = container.resolve()
        else {
            return nil
        }
        return Dependencies(
            eventLog: eventLog,
            installation: installation,
            sessions: sessions,
            analytics: analytics,
            logReader: logReader
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
            logReader: dependencies.logReader
        )
        return DiagnosticsView(viewModel: viewModel)
    }
}
#endif
