/// Builds the product details screen from the container. `resolveDependencies(from:)` is the
/// registration guard that `AppContextRegistrationTests` checks.
@MainActor
enum ProductDetailConfigurator {
    struct Dependencies {
        let analytics: any AnalyticsTracking
    }

    static func resolveDependencies(from container: any ServiceContainerType) -> Dependencies? {
        guard let analytics: any AnalyticsTracking = container.resolve() else { return nil }
        return Dependencies(analytics: analytics)
    }

    static func make(from container: any ServiceContainerType, route: ProductDetailRoute) -> ProductDetailView {
        guard let dependencies = resolveDependencies(from: container) else {
            preconditionFailure("ProductDetailConfigurator: a service is not registered; see AppContextRegistrationTests")
        }
        return ProductDetailView(viewModel: ProductDetailViewModel(route: route, analytics: dependencies.analytics))
    }
}
