import SwiftUI

@main
struct MerchantCatalogApp: App {
    /// Built once at launch. Scene Configurators resolve services from `context.container` (S2+).
    private let context = AppContext.configure()

    var body: some Scene {
        WindowGroup {
            Text("MerchantCatalog")
        }
    }
}
