/// Builds the product details screen from the container. `resolveDependencies(from:)` is the
/// registration guard that `AppContextRegistrationTests` checks.
@MainActor
enum ProductDetailConfigurator {
    struct Dependencies {
        let repository: any ProductRepository
        let savedProducts: SavedProductsStore
        let analytics: any AnalyticsTracking
    }

    static func resolveDependencies(from container: any ServiceContainerType) -> Dependencies? {
        guard
            let repository: any ProductRepository = container.resolve(),
            let savedProducts: SavedProductsStore = container.resolve(),
            let analytics: any AnalyticsTracking = container.resolve()
        else {
            return nil
        }
        return Dependencies(repository: repository, savedProducts: savedProducts, analytics: analytics)
    }

    static func make(from container: any ServiceContainerType, route: ProductDetailRoute) -> ProductDetailView {
        guard let dependencies = resolveDependencies(from: container) else {
            preconditionFailure("ProductDetailConfigurator: a service is not registered; see AppContextRegistrationTests")
        }
        let viewModel = ProductDetailViewModel(
            route: route,
            repository: dependencies.repository,
            savedProducts: dependencies.savedProducts,
            analytics: dependencies.analytics
        )
        return ProductDetailView(viewModel: viewModel)
    }
}
