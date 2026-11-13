import SwiftUI

/// The app's root: two tabs, each with its own `NavigationStack` and `Router`, so the tab bar stays
/// visible on push and each tab keeps its own back stack.
///
/// Navigation rule (enforced by `NavigationRuleTests`): this is the only file that uses
/// `NavigationStack` or `navigationDestination`. Destinations are built here; tab roots and
/// destinations come from scene Configurators.
///
/// It owns only the tab selection (`TabSelection`, D-61), the routers and the Diagnostics sheet
/// flag; each tab's screen owns its own view model. The Catalog screen gets `isTabSelected` for `catalog_viewed` (D-39).
///
/// DEBUG builds add a Diagnostics toolbar button on the Catalog tab (ProductSpecification § 3).
struct AppTabView: View {
    let container: any ServiceContainerType

    @State private var tabs = TabSelection()
    @State private var catalogRouter = Router()
    @State private var savedRouter = Router()
    #if DEBUG
    @State private var isShowingDiagnostics = false
    #endif

    var body: some View {
        TabView(selection: $tabs.selected) {
            Tab("Catalog", systemImage: "square.grid.2x2", value: AppTab.catalog) {
                NavigationStack(path: $catalogRouter.path) {
                    CatalogConfigurator.make(from: container, router: catalogRouter, isTabSelected: tabs.selected == .catalog)
                    #if DEBUG
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Diagnostics", systemImage: "stethoscope") {
                                isShowingDiagnostics = true
                            }
                        }
                    }
                    #endif
                    .navigationDestination(for: Route.self) { route in
                        destination(for: route)
                    }
                }
            }

            Tab("Saved", systemImage: "bookmark", value: AppTab.saved) {
                NavigationStack(path: $savedRouter.path) {
                    ContentUnavailableView(
                        "Saved",
                        systemImage: "bookmark",
                        description: Text("Saved products will appear here.")
                    )
                    .navigationTitle("Saved")
                    .navigationDestination(for: Route.self) { route in
                        destination(for: route)
                    }
                }
            }
        }
        .onChange(of: tabs.selected) { _, tab in
            Log.navigation.debug("tab \(String(describing: tab), privacy: .public)")
        }
        #if DEBUG
        .sheet(isPresented: $isShowingDiagnostics) {
            NavigationStack {
                DiagnosticsConfigurator.make(from: container)
            }
        }
        #endif
    }

    /// Builds each pushed screen through its Configurator.
    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .productDetail(let route):
            ProductDetailConfigurator.make(from: container, route: route)
        }
    }
}

#Preview {
    AppTabView(container: AppContext.configure().container)
}
