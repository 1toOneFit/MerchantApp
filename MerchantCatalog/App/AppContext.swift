import Foundation

/// Composition root: the only place that names concrete service types.
///
/// `configure()` runs once at launch (`MerchantCatalogApp`) and registers every service under its
/// protocol type. Each call builds a new container, so there is no global mutable state and every
/// test gets an isolated container.
///
/// Registration guard: each scene Configurator resolves its services in
/// `static func resolveDependencies(from: any ServiceContainerType) -> Dependencies?`, which its
/// `make(...)` also uses; `AppContextRegistrationTests` calls it against `configure().container`.
@MainActor
final class AppContext {
    let container: any ServiceContainerType
    /// Receives scene-phase changes from `MerchantCatalogApp`.
    let lifecycle: AppLifecycleTracker
    /// The saved products every screen and the tab badge read; `MerchantCatalogApp` loads it once at
    /// launch. Also registered in the container.
    let savedProducts: SavedProductsStore

    private init(container: any ServiceContainerType, lifecycle: AppLifecycleTracker, savedProducts: SavedProductsStore) {
        self.container = container
        self.lifecycle = lifecycle
        self.savedProducts = savedProducts
    }

    /// - Parameters:
    ///   - defaults: where the installation id and session bookkeeping live; tests pass an
    ///     isolated suite.
    ///   - appInfo: the launch user properties' source.
    ///   - savedProductsDirectory: holds the saved-products file (Architecture § 9); nothing is read
    ///     until the store's `load()`.
    static func configure(
        defaults: UserDefaults = .standard,
        appInfo: AppInfo = .current(),
        savedProductsDirectory: URL = .applicationSupportDirectory
    ) -> AppContext {
        let container = ServiceContainer()

        let installation = InstallationIDProvider(defaults: defaults)
        let sessions = SessionTracker(defaults: defaults)
        var providers: [any AnalyticsProvider] = [LoggingAnalyticsProvider()]
        #if DEBUG
        let eventLog = InMemoryAnalyticsProvider()
        providers.append(eventLog)
        container.register(eventLog)
        container.register(OSLogStoreReader(subsystem: Log.subsystem) as any LogReading)
        #endif
        let analytics = AnalyticsService(providers: providers, installation: installation, sessions: sessions)

        container.register(analytics as any AnalyticsTracking)
        container.register(installation)
        container.register(sessions)

        // One delay shared by the client (reads it per request) and, in DEBUG, the slow-network
        // toggle (writes it).
        let requestDelay = RequestDelay()
        let client = URLSessionAPIClient(delay: requestDelay)
        container.register(client as any APIClientType)
        container.register(LiveProductRepository(client: client) as any ProductRepository)
        let savedRepository: any SavedProductsRepository = FileSavedProductsRepository(directory: savedProductsDirectory)
        // `as any` keeps the key the protocol: an existential passed to a generic parameter is
        // otherwise opened, and the service would be registered under the concrete type.
        container.register(savedRepository as any SavedProductsRepository)
        let savedProducts = SavedProductsStore(repository: savedRepository, analytics: analytics)
        container.register(savedProducts)
        #if DEBUG
        container.register(SlowNetworkSetting(defaults: defaults, requestDelay: requestDelay))
        #endif

        for property in UserProperty.launchProperties(app: appInfo, firstSeenDate: installation.firstSeenDate) {
            analytics.setUserProperty(property)
        }

        let lifecycle = AppLifecycleTracker(analytics: analytics, sessions: sessions)
        return AppContext(container: container, lifecycle: lifecycle, savedProducts: savedProducts)
    }
}
