/// Builds the Saved screen from the container. `resolveDependencies(from:)` is the registration
/// guard that `AppContextRegistrationTests` checks.
@MainActor
enum SavedConfigurator {
    struct Dependencies {
        let savedProducts: SavedProductsStore
        let analytics: any AnalyticsTracking
    }

    static func resolveDependencies(from container: any ServiceContainerType) -> Dependencies? {
        guard
            let savedProducts: SavedProductsStore = container.resolve(),
            let analytics: any AnalyticsTracking = container.resolve()
        else {
            return nil
        }
        return Dependencies(savedProducts: savedProducts, analytics: analytics)
    }

    /// - Parameters:
    ///   - router: the Saved tab's router, owned by `AppTabView`.
    ///   - tabs: the tab selection, owned by `AppTabView` (D-61).
    ///   - isTabSelected: whether the Saved tab is the selected tab (`saved_products_viewed`, D-39).
    static func make(from container: any ServiceContainerType, router: Router, tabs: TabSelection, isTabSelected: Bool) -> SavedView {
        guard let dependencies = resolveDependencies(from: container) else {
            preconditionFailure("SavedConfigurator: a service is not registered; see AppContextRegistrationTests")
        }
        let viewModel = SavedViewModel(savedProducts: dependencies.savedProducts, analytics: dependencies.analytics, router: router, tabs: tabs)
        return SavedView(viewModel: viewModel, isTabSelected: isTabSelected)
    }
}
