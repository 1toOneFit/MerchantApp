/// The app's service container. Keys are the exact registered type (`ObjectIdentifier(T.self)`),
/// so two types that share a name in different scopes never collide, as they would with
/// `String(describing:)` keys.
@MainActor
final class ServiceContainer: ServiceContainerType {
    private var services: [ObjectIdentifier: Any] = [:]

    init() {}

    func register<T>(_ service: T) {
        services[ObjectIdentifier(T.self)] = service
    }

    func resolve<T>() -> T? {
        services[ObjectIdentifier(T.self)] as? T
    }

    func forceResolve<T>() -> T {
        guard let service: T = resolve() else {
            fatalError("ServiceContainer: no service registered for \(T.self)")
        }
        return service
    }
}
