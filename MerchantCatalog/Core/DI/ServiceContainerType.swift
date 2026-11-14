/// Registers services under the type they are declared as and resolves them by that type.
///
/// Register infrastructure under its protocol (`container.register(client as any APIClientType)`)
/// so consumers depend only on the protocol. Only `AppContext` registers services; Configurators
/// resolve them and inject them into view models through initializers.
@MainActor
protocol ServiceContainerType: AnyObject {
    /// Stores `service` under `T`. Registering the same `T` again replaces the previous service.
    func register<T>(_ service: T)
    /// Returns the service registered under exactly `T`, or `nil`.
    func resolve<T>() -> T?
    /// Returns the service registered under `T`; traps with the type name when it is missing.
    func forceResolve<T>() -> T
}
