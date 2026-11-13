/// Builds the catalog's view model from the container. `resolveDependencies(from:)` is the
/// registration guard that `AppContextRegistrationTests` checks.
///
/// `AppTabView` owns the view model (it also tells it when the Catalog tab becomes visible, D-39),
/// so this returns the view model rather than the view.
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

    static func makeViewModel(from container: any ServiceContainerType) -> CatalogViewModel {
        guard let dependencies = resolveDependencies(from: container) else {
            preconditionFailure("CatalogConfigurator: a service is not registered; see AppContextRegistrationTests")
        }
        return CatalogViewModel(repository: dependencies.repository, analytics: dependencies.analytics)
    }
}
