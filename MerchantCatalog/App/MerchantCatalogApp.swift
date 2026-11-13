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
            AppTabView(container: context.container)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            context.lifecycle.handle(AppPhase(phase))
        }
    }
}
