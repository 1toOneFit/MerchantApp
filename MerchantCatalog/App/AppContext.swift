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

    private init(container: any ServiceContainerType) {
        self.container = container
    }

    static func configure() -> AppContext {
        let container = ServiceContainer()
        // Services are registered here from S1 on, each under its protocol type.
        return AppContext(container: container)
    }
}
