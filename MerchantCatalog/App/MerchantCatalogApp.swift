import SwiftUI

@main
struct MerchantCatalogApp: App {
    /// Built once at launch. Scene Configurators resolve services from `context.container` (S2+).
    private let context: AppContext

    init() {
        context = AppContext.configure()
        Log.lifecycle.info("App launched")
    }

    var body: some Scene {
        WindowGroup {
            AppTabView()
        }
    }
}
