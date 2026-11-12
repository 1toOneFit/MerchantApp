import Testing
@testable import MerchantCatalog

private protocol GreeterType: AnyObject {
    func greet() -> String
}

private final class Greeter: GreeterType {
    func greet() -> String { "hi" }
}

private struct Counter: Equatable {
    let value: Int
}

/// Two types that share the name `Config` in different scopes.
private enum ScopeA {
    struct Config: Equatable { let value: Int }
}

private enum ScopeB {
    struct Config: Equatable { let value: Int }
}

@MainActor
struct ServiceContainerTests {
    private let container = ServiceContainer()

    @Test func registerThenResolveReturnsTheSameInstance() throws {
        let greeter = Greeter()
        container.register(greeter as any GreeterType)

        let resolved = try #require(container.resolve() as (any GreeterType)?)
        #expect(resolved === greeter)

        let forced: any GreeterType = container.forceResolve()
        #expect(forced.greet() == "hi")
    }

    @Test func resolveMissingReturnsNil() {
        #expect(container.resolve() as (any GreeterType)? == nil)
    }

    @Test func registeringTheSameTypeTwiceOverwrites() {
        container.register(Counter(value: 1))
        container.register(Counter(value: 2))

        #expect(container.resolve() as Counter? == Counter(value: 2))
    }

    @Test func resolvesOnlyUnderTheRegisteredType() {
        container.register(Greeter() as any GreeterType)

        #expect(container.resolve() as (any GreeterType)? != nil)
        #expect(container.resolve() as Greeter? == nil)
    }

    @Test func sameNamedTypesInDifferentScopesDoNotCollide() {
        container.register(ScopeA.Config(value: 1))
        container.register(ScopeB.Config(value: 2))

        #expect(container.resolve() as ScopeA.Config? == ScopeA.Config(value: 1))
        #expect(container.resolve() as ScopeB.Config? == ScopeB.Config(value: 2))
    }
}
