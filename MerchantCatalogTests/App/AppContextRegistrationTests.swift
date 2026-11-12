import Testing
@testable import MerchantCatalog

private struct Marker: Equatable {
    let id: Int
}

/// Guards the composition root.
///
/// From S2 on, every scene Configurator gets a test here asserting that its
/// `resolveDependencies(from:)` returns non-nil against `AppContext.configure().container`,
/// so a missing registration fails a test instead of trapping in `forceResolve` at runtime.
/// S0 has no Configurator yet.
@MainActor
struct AppContextRegistrationTests {
    @Test func configureBuildsAnIndependentContainer() {
        let first = AppContext.configure()
        first.container.register(Marker(id: 1))

        let second = AppContext.configure()

        #expect(second.container.resolve() as Marker? == nil)
        #expect(first.container.resolve() as Marker? == Marker(id: 1))
    }
}
