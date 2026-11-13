import SwiftUI

/// The app's root: two tabs, each with its own `NavigationStack` and `Router`, so the tab bar stays
/// visible on push and each tab keeps its own back stack.
///
/// Navigation rule (enforced by `NavigationRuleTests`): this is the only file that uses
/// `NavigationStack` or `navigationDestination`. Destinations are built here; tab roots and
/// destinations come from scene Configurators.
///
/// It owns the catalog's view model and tells it when the Catalog tab becomes visible: at launch
/// and on each switch back, not when popping back from details (D-39).
///
/// DEBUG builds add a Diagnostics toolbar button on the Catalog tab (ProductSpecification § 3).
struct AppTabView: View {
    let container: any ServiceContainerType

    @State private var selection: AppTab = .catalog
    @State private var catalogRouter = Router()
    @State private var savedRouter = Router()
    @State private var catalogViewModel: CatalogViewModel
    #if DEBUG
    @State private var isShowingDiagnostics = false
    #endif

    init(container: any ServiceContainerType) {
        self.container = container
        _catalogViewModel = State(initialValue: CatalogConfigurator.makeViewModel(from: container))
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Catalog", systemImage: "square.grid.2x2", value: AppTab.catalog) {
                NavigationStack(path: $catalogRouter.path) {
                    CatalogView(viewModel: catalogViewModel)
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
        .onChange(of: selection, initial: true) { _, tab in
            Log.navigation.debug("tab \(String(describing: tab), privacy: .public)")
            if tab == .catalog {
                catalogViewModel.catalogBecameVisible()
            }
        }
        #if DEBUG
        .sheet(isPresented: $isShowingDiagnostics) {
            NavigationStack {
                DiagnosticsConfigurator.make(from: container)
            }
        }
        #endif
    }

    /// S0 placeholder; S4 builds the product details screen through its Configurator.
    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .productDetail(let productID):
            Text("Product \(productID)")
        }
    }
}

#Preview {
    AppTabView(container: AppContext.configure().container)
}
