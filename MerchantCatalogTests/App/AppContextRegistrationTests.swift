import Foundation
import Testing
@testable import MerchantCatalog

private struct Marker: Equatable {
    let id: Int
}

/// Guards the composition root.
///
/// Every scene Configurator gets a test here asserting that its `resolveDependencies(from:)`
/// returns non-nil against `AppContext.configure().container`, so a missing registration fails a
/// test instead of trapping in `forceResolve` at runtime.
@MainActor
struct AppContextRegistrationTests {
    private let store = IsolatedDefaults()

    private static let appInfo = AppInfo(
        appVersion: "1.0",
        buildNumber: "1",
        osVersion: "26.0",
        deviceModel: "iPhone18,3",
        isDebugBuild: true
    )

    private func configure() -> AppContext {
        AppContext.configure(defaults: store.defaults, appInfo: Self.appInfo)
    }

    @Test func configureBuildsAnIndependentContainer() {
        let first = configure()
        first.container.register(Marker(id: 1))

        let second = configure()

        #expect(second.container.resolve() as Marker? == nil)
        #expect(first.container.resolve() as Marker? == Marker(id: 1))
    }

    @Test func analyticsServicesAreRegistered() {
        let container = configure().container

        #expect(container.resolve() as (any AnalyticsTracking)? != nil)
        #expect(container.resolve() as InstallationIDProvider? != nil)
        #expect(container.resolve() as SessionTracker? != nil)
    }

    @Test func networkServicesAreRegistered() {
        let container = configure().container

        #expect(container.resolve() as (any APIClientType)? != nil)
        #expect(container.resolve() as (any ProductRepository)? != nil)
    }

    /// Review finding 2: the saved repository is registered by its protocol, like every other
    /// infrastructure service (Architecture § 4).
    @Test func savedRepositoryIsRegisteredByProtocol() {
        let container = configure().container

        #expect(container.resolve() as (any SavedProductsRepository)? != nil)
    }

    /// The store reads and writes through that same registered repository.
    @Test func savedStoreUsesTheRegisteredRepository() async throws {
        let directory = TemporaryDirectory()
        let context = AppContext.configure(defaults: store.defaults, appInfo: Self.appInfo, savedProductsDirectory: directory.url)
        let repository = try #require(context.container.resolve() as (any SavedProductsRepository)?)
        let item = SavedProduct(product(3), savedAt: date("2026-11-13T10:00:00Z"))

        await repository.save([item])
        await context.savedProducts.load()

        #expect(context.savedProducts.items == [item])
    }

    @Test func experimentServiceIsRegisteredByProtocol() {
        let container = configure().container

        #expect(container.resolve() as (any ExperimentService)? != nil)
        #if DEBUG
        #expect(container.resolve() as (any ExperimentOverrides)? != nil)
        #endif
    }

    @Test func catalogDependenciesResolve() {
        #expect(CatalogConfigurator.resolveDependencies(from: configure().container) != nil)
    }

    @Test func savedDependenciesResolve() {
        #expect(SavedConfigurator.resolveDependencies(from: configure().container) != nil)
    }

    /// Every screen and the tab badge read one store (AC-V1).
    @Test func savedStoreIsShared() {
        let context = configure()

        #expect(context.container.resolve() as SavedProductsStore? === context.savedProducts)
    }

    @Test func productDetailDependenciesResolve() {
        #expect(ProductDetailConfigurator.resolveDependencies(from: configure().container) != nil)
    }

    #if DEBUG
    @Test func diagnosticsDependenciesResolve() {
        #expect(DiagnosticsConfigurator.resolveDependencies(from: configure().container) != nil)
    }

    /// The toggle and the registered client share one `RequestDelay` (D-42).
    @Test func slowNetworkSettingReachesTheAPIClient() throws {
        let container = configure().container
        let setting = try #require(container.resolve() as SlowNetworkSetting?)
        let client = try #require(container.resolve() as (any APIClientType)? as? URLSessionAPIClient)

        setting.isEnabled = true

        #expect(client.delay.value == SlowNetworkSetting.delay)
    }

    @Test func launchUserPropertiesReachTheEventLog() throws {
        let container = configure().container
        let eventLog = try #require(container.resolve() as InMemoryAnalyticsProvider?)
        let installation = try #require(container.resolve() as InstallationIDProvider?)

        #expect(eventLog.userProperties == [
            "app_version": .string("1.0"),
            "build_number": .string("1"),
            "os_version": .string("26.0"),
            "device_model": .string("iPhone18,3"),
            "first_seen_date": UserProperty.firstSeenDate(installation.firstSeenDate).value,
            "is_debug_build": .bool(true),
            "experiment_assignments": .stringMap([
                "product_card_density_v1": ExperimentAssigner.variant(for: .productCardDensity, installationID: installation.installationID).rawValue,
            ]),
        ])
    }

    /// The lifecycle tracker and the service share one session tracker, so the cold session the
    /// first `.active` starts is the one every later event carries.
    @Test func lifecycleEventsReachTheEventLog() throws {
        let context = configure()
        let eventLog = try #require(context.container.resolve() as InMemoryAnalyticsProvider?)
        let sessions = try #require(context.container.resolve() as SessionTracker?)

        context.lifecycle.handle(.active)
        context.lifecycle.handle(.background)

        let session = try #require(sessions.current)
        #expect(eventLog.events.map(\.event.name) == [.sessionStarted, .appBackgrounded])
        #expect(eventLog.events.map(\.sessionID) == [session.id, session.id])
    }
    #endif
}
