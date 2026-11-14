/// Builds the catalog screen from the container. `resolveDependencies(from:)` is the registration
/// guard that `AppContextRegistrationTests` checks.
@MainActor
enum CatalogConfigurator {
    struct Dependencies {
        let repository: any ProductRepository
        let analytics: any AnalyticsTracking
        let savedProducts: SavedProductsStore
        let experiments: any ExperimentService
        let exposure: ExposureTracker
    }

    static func resolveDependencies(from container: any ServiceContainerType) -> Dependencies? {
        guard
            let repository: any ProductRepository = container.resolve(),
            let analytics: any AnalyticsTracking = container.resolve(),
            let savedProducts: SavedProductsStore = container.resolve(),
            let experiments: any ExperimentService = container.resolve(),
            let exposure: ExposureTracker = container.resolve()
        else {
            return nil
        }
        return Dependencies(
            repository: repository,
            analytics: analytics,
            savedProducts: savedProducts,
            experiments: experiments,
            exposure: exposure
        )
    }

    /// - Parameters:
    ///   - router: the Catalog tab's router, owned by `AppTabView` (D-53).
    ///   - isTabSelected: whether the Catalog tab is the selected tab (D-39).
    static func make(from container: any ServiceContainerType, router: Router, isTabSelected: Bool) -> CatalogView {
        guard let dependencies = resolveDependencies(from: container) else {
            preconditionFailure("CatalogConfigurator: a service is not registered; see AppContextRegistrationTests")
        }
        let viewModel = CatalogViewModel(
            repository: dependencies.repository,
            analytics: dependencies.analytics,
            router: router,
            savedProducts: dependencies.savedProducts,
            cardExperiment: CardExperiment(
                assignment: dependencies.experiments.assignment(for: .productCardDensity),
                exposure: dependencies.exposure
            )
        )
        return CatalogView(viewModel: viewModel, isTabSelected: isTabSelected)
    }
}
