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
}
