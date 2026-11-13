/// Builds the catalog screen from the container. `resolveDependencies(from:)` is the registration
/// guard that `AppContextRegistrationTests` checks.
@MainActor
enum CatalogConfigurator {
    struct Dependencies {
        let repository: any ProductRepository
        let analytics: any AnalyticsTracking
    }

    static func resolveDependencies(from container: any ServiceContainerType) -> Dependencies? {
        guard
            let repository: any ProductRepository = container.resolve(),
            let analytics: any AnalyticsTracking = container.resolve()
        else {
            return nil
        }
        return Dependencies(repository: repository, analytics: analytics)
    }

    /// - Parameters:
    ///   - router: the Catalog tab's router, owned by `AppTabView` (D-53).
    ///   - isTabSelected: whether the Catalog tab is the selected tab (D-39).
    static func make(from container: any ServiceContainerType, router: Router, isTabSelected: Bool) -> CatalogView {
        guard let dependencies = resolveDependencies(from: container) else {
            preconditionFailure("CatalogConfigurator: a service is not registered; see AppContextRegistrationTests")
        }
        let viewModel = CatalogViewModel(repository: dependencies.repository, analytics: dependencies.analytics, router: router)
        return CatalogView(viewModel: viewModel, isTabSelected: isTabSelected)
    }
}
