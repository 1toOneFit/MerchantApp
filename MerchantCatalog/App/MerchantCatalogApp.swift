import SwiftUI

@main
struct MerchantCatalogApp: App {
    /// The app-wide phase (active if any scene is), which drives lifecycle analytics.
    @Environment(\.scenePhase) private var scenePhase

    /// Built once at launch. Scene Configurators resolve services from `context.container`.
    private let context: AppContext

    init() {
        context = AppContext.configure()
        Log.lifecycle.info("App launched")
    }

    var body: some Scene {
        WindowGroup {
            AppTabView(container: context.container, savedProducts: context.savedProducts)
                // Every `ProductImageView` loads through the registered loader (D-78).
                .environment(\.imageLoader, context.imageLoader)
                // Reads the saved list once, off the main actor (Architecture § 9).
                .task { await context.savedProducts.load() }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            context.lifecycle.handle(AppPhase(phase))
        }
    }
}
