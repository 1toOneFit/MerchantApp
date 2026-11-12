# Architecture — MerchantCatalog

**Status:** Approved by the developer (2026-11-13). Describes the target design; each stage updates this file when reality differs.

## 1. Summary

| Concern | Choice | Alternative considered |
|---|---|---|
| UI | SwiftUI, iOS 26.0 minimum, Xcode 26.0 | UIKit: no benefit for this scope |
| Pattern | Clean Architecture + MVVM, feature folders with `Domain` / `Data` / `Presentation` | TCA: used by many teams, but not the developer's working knowledge. MVVM with explicit intents is explainable end to end |
| State | `@MainActor @Observable` view models exposing a state value + intent methods | `ObservableObject`/Combine (previous projects): Observation is simpler and tracks only the properties a view reads |
| Concurrency | Swift 6 language mode, strict concurrency, structured async/await | Combine pipelines: more ceremony, weaker cancellation story |
| Infrastructure boundaries | **Protocol-first**: `APIClientType`, `AnalyticsTracking` + `AnalyticsProvider`, repository protocols | Concrete singletons: impossible to swap or fake |
| DI | `ServiceContainer` (register/resolve) configured once at launch; scene **Configurators** resolve services and build view models | Pure init injection from a composition root: compile-time safer. The container is kept for consistency with the developer's established architecture |
| Networking | Moya-style `TargetType` endpoints + `URLSessionAPIClient` (async) | Alamofire: unnecessary dependency |
| Caching | **None**: `urlCache = nil`, every request hits the network | `URLCache` (headers give no freshness; images are `no-store`); custom caches (too much for this scope). See [Networking.md § 3](Networking.md#3-caching--deliberately-not-implemented) |
| Images | `AsyncImage`, rendered only while the cell is visible (load on appear, torn down on disappear) | Custom image loader with de-duplication and cache: more control, more code than this scope needs |
| Navigation | Two tabs, one `NavigationStack` per tab, a `Router` per tab with a `Route` enum | Single root stack around the `TabView`: hides the tab bar on push |
| Persistence | JSON file in Application Support behind a repository protocol (saved snapshots only) | SwiftData: heavier, harder to test, no relational need |
| Logging | `os.Logger` with categories; the DEBUG viewer reads `OSLogStore` | Print-based logger: loses levels, privacy redaction and Console.app integration |
| Tests | Swift Testing, hand-written fakes, `URLProtocol` stub for HTTP | XCTest: fine, but Swift Testing's parameterized tests suit endpoint, sort and taxonomy tables |
| Modules | Single app target with folder boundaries | Local SPM packages: worthwhile once a second app or extension shares code |

## 2. Folder structure

```text
MerchantCatalog/                       # app target (file-system-synchronized groups)
  App/
    MerchantCatalogApp.swift           # @main; AppContext.configure(); scenePhase → lifecycle analytics
    AppContext.swift                   # registers concrete services under their protocols
    AppTabView.swift                   # TabView + the ONLY NavigationStacks / navigationDestination
    AppTab.swift                       # .catalog / .saved
  Core/
    DI/            ServiceContainerType.swift, ServiceContainer.swift
    Navigation/    Router.swift, Route.swift
    Logging/       Log.swift (Logger categories)
    Analytics/     AnalyticsTracking.swift (protocol), AnalyticsProvider.swift (protocol),
                   AnalyticsEvent.swift, AnalyticsService.swift (AnalyticsTracking impl, fans out),
                   Providers/ (LoggingAnalyticsProvider, InMemoryAnalyticsProvider [DEBUG]),
                   SessionTracker.swift, InstallationIDProvider.swift, UserProperties.swift
    Experiments/   Experiment.swift, ExperimentAssigner.swift, ExperimentService.swift, ExposureTracker.swift
    Persistence/   JSONFileStore.swift (atomic write, corrupt-file quarantine)
  Networking/
    APIClientType.swift (protocol), URLSessionAPIClient.swift, TargetType.swift, HTTPMethod.swift,
    APIConfig.swift, AppError.swift, HTTPStatusCode.swift, NetworkLogger.swift
  Shared/
    Products/
      Domain/      Product, ProductPage, ProductQuery, ProductSort, ProductRepository (protocol),
                   ProductInsights (facts builder)
      Data/        ProductsTarget, ProductDTO (+ mapping), LiveProductRepository
    Saved/
      Domain/      SavedProduct (snapshot), SavedProductsRepository (protocol)
      Data/        FileSavedProductsRepository
      SavedProductsStore.swift         # @MainActor @Observable source of truth shared by all screens
  Features/
    Catalog/
      Domain/      CatalogListState (pure pagination/de-dup state), SearchDebouncer
      Presentation/ CatalogView, CatalogViewModel, CatalogConfigurator, ProductCardView, SortMenu
    ProductDetail/
      Presentation/ ProductDetailView, ProductDetailViewModel, ProductDetailConfigurator,
                    GalleryView, AtAGlanceView
    Saved/
      Presentation/ SavedView, SavedViewModel, SavedConfigurator
    Diagnostics/                        # compiled in DEBUG only
      Presentation/ DiagnosticsView (events, user properties, experiment override,
                    slow network, logs, reset installation ID)
  DesignSystem/
    Theme/         Spacing, Typography (system styles only)
    Components/    ProductImageView (visibility-gated AsyncImage), StateViews (Loading/Empty/Error),
                   ErrorBanner, SaveButton
  Assets.xcassets                       # AppIcon (empty until an icon is added), AccentColor
MerchantCatalogTests/
  Fakes/           FakeAPIClient, StubURLProtocol, FakeProductRepository, TestClock,
                   InMemorySavedRepository, SpyAnalytics, SpyAnalyticsProvider, …
  …Tests.swift     mirror the app folders
```

`Shared/` holds domain and data used by more than one feature (products, saved items). A feature folder holds only what that feature uses. Test doubles live in the test target only. DEBUG-only runtime tooling lives in `Features/Diagnostics`.

**What exists (S0):** the tree above is the target layout. S0 created `App/` (`MerchantCatalogApp`, `AppContext`, `AppTab`, `AppTabView`), `Core/DI`, `Core/Navigation`, `Core/Logging` and `Assets.xcassets`, plus tests in `MerchantCatalogTests/App` and `MerchantCatalogTests/Core/{DI,Navigation}`. Every other folder is created together with its first file: git doesn't track empty folders, and a placeholder file inside a file-system-synchronized folder would be copied into the app bundle.

## 3. Layer rules

- **Domain:** pure Swift value types (`Sendable`), repository protocols, and business rules (pagination state machine, insights builder, assignment hashing). No `SwiftUI`, no `URLSession`, no DTOs.
- **Data:** `TargetType` endpoints, DTOs, DTO → domain mapping, repository implementations. DTOs never leave this layer.
- **Presentation:** SwiftUI views render state and forward user intents. View models own presentation state, call repositories/services through protocols, and emit analytics. Views do not call repositories, analytics or the router directly; they call view-model intents.
- Dependencies point inward: Presentation → Domain ← Data.

## 4. Protocol-first infrastructure

Every piece of infrastructure a feature uses sits behind a protocol, so implementations can be replaced without touching the protocol or its callers.

| Capability | Protocol (what callers see) | 1.0 implementation(s) | How to extend |
|---|---|---|---|
| HTTP | `APIClientType` | `URLSessionAPIClient` | Write another conforming client and register it in `AppContext` |
| Analytics (callers) | `AnalyticsTracking`: `track(_:)`, `setUserProperty(_:)` | `AnalyticsService` (envelope enrichment + fan-out) | — |
| Analytics (destinations) | `AnalyticsProvider`: receives enriched events and user-property changes | `LoggingAnalyticsProvider`, `InMemoryAnalyticsProvider` (DEBUG) | Add e.g. an Amplitude/Firebase provider type; register it with `AnalyticsService`. No change to `AnalyticsTracking`, events or view models |
| Products | `ProductRepository` | `LiveProductRepository` | — |
| Saved items | `SavedProductsRepository` | `FileSavedProductsRepository` | — |
| Experiments | `ExperimentService` protocol | `LocalExperimentService` | A remote-config implementation later |

Rules: services are registered in the container **as their protocol type**; view models and repositories receive protocols through their initializers; only `AppContext` names concrete types. Tests prove the swap: `AnalyticsService` delivers every event to every registered provider (spy providers), and repositories run against `FakeAPIClient`.

## 5. Concurrency model

- **Swift 6 language mode with complete strict-concurrency checking.** Zero warnings is a review requirement. Before each stage, confirm the project's Swift version, deployment target and concurrency settings.
- **Build settings** (verified 2026-11-13 in S0 with `xcodebuild -showBuildSettings`): `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0` on both targets. `SWIFT_DEFAULT_ACTOR_ISOLATION` and `SWIFT_APPROACHABLE_CONCURRENCY` are deliberately not set, although Xcode 26 templates usually enable them: code is nonisolated by default, and `@MainActor` is written explicitly on the UI-facing types listed below.
- **Structured first.** Work starts from SwiftUI's `.task`/`.refreshable` or from async view-model intents, so cancellation follows the view lifecycle automatically. Unstructured `Task { }` is used only where a synchronous UI callback must start async work (e.g. a button tap or text change); the view model keeps the handle and cancels it on supersession or teardown.
- **Explicit isolation.** `@MainActor` on UI-facing types only: view models, routers, `SavedProductsStore`, `ServiceContainer`, `ExposureTracker`. Domain models and DTOs are `Sendable` value types. `URLSessionAPIClient` and repositories are `Sendable` (immutable configuration). File writes go through an **actor**. No `@unchecked Sendable` or `nonisolated(unsafe)` without a justifying comment.
- **Cancellation propagates.** `URLSession`'s async API cancels the network task when the Swift task is cancelled. `CancellationError` / `URLError.cancelled` means "no state change", never an error UI.
- **Debounce** uses an injected `any Clock<Duration>`: `ContinuousClock` in the app and a hand-written `TestClock` in tests, so timing tests are deterministic.
- **Stale-response protection:** every list request carries a monotonically increasing generation number. A result whose generation isn't current is dropped even if cancellation lost the race.
- Validated with an Xcode build and the test suite after every concurrency change.

## 6. Dependency injection

Kept from the developer's previous architecture, adapted to Swift 6:

```swift
@MainActor
protocol ServiceContainerType: AnyObject {
    func register<T>(_ service: T)
    func resolve<T>() -> T?
    func forceResolve<T>() -> T
}
```

- `AppContext.configure()` runs once at launch and registers, by protocol: `APIClientType`, `ProductRepository`, `SavedProductsRepository`, `AnalyticsTracking`, `ExperimentService`, plus `SavedProductsStore`, `SessionTracker`, `InstallationIDProvider`. Each call returns a new `AppContext` with a new container; the app keeps the one built at launch. There is no global singleton, and every test gets an isolated container.
- `ServiceContainer` keys services by `ObjectIdentifier(T.self)`, the exact registered type. `String(describing:)` keys collide for same-named types in different scopes; an S0 test showed this.
- Each scene has a **Configurator** (`CatalogConfigurator.make(router:)`) that resolves services and builds the view model with **init injection**. View models never touch the container, so unit tests construct them directly with fakes.
- **Registration guard** (developer's choice, 2026-11-13): each Configurator resolves its services in `static func resolveDependencies(from: any ServiceContainerType) -> Dependencies?`, which returns `nil` if anything is missing, and its `make(...)` uses the same function. `AppContextRegistrationTests` calls every Configurator's `resolveDependencies(from:)` against `AppContext.configure().container`, so a missing registration fails a test instead of crashing in `forceResolve`. S0 has no Configurator; the first real case arrives in S2.

## 7. Navigation

```swift
enum Route: Hashable {
    case productDetail(ProductDetailRoute)   // id, optional preloaded Product, optional SavedProduct, source
}

@MainActor @Observable
final class Router {
    var path: [Route] = []
    func showProductDetail(_ route: ProductDetailRoute)
    func pop()
    func popToRoot()
}
```

- **S0 state:** `Route` has one placeholder case, `productDetail(productID: Int)`, with a text placeholder destination: an uninhabited enum couldn't be pushed or tested. S4 introduces `ProductDetailRoute` and `showProductDetail(_:)`. The S0 `Router` API is `path`, `push(_:)`, `pop()` and `popToRoot()`; both pops do nothing at the root.
- One `Router` per tab, owned by `AppTabView`. `AppTabView` hosts the two `NavigationStack(path:)` and the single `navigationDestination(for: Route.self)` switch that calls Configurators.
- **Navigation rule** (enforced by `NavigationRuleTests`, a source scan): `NavigationStack` and `navigationDestination` appear only in `App/AppTabView.swift`; `NavigationLink` and `NavigationView` appear nowhere. Feature views request navigation through view-model intents that call the router.
- Tab switching (e.g. the Saved empty state's "Browse catalog") goes through an `@Observable` tab selection owned by `AppTabView`.

## 8. Presentation state

Each list screen uses an explicit state value rather than loose booleans:

```swift
enum CatalogPhase: Equatable {
    case initialLoading
    case content(isLoadingMore: Bool, isRefreshing: Bool, pageError: AppError?)
    case empty
    case failed(AppError)
}
```

`CatalogListState` (Domain) is a pure struct owning the items, the `id` set for de-duplication, `total`, the next `skip`, and `canLoadMore`. The view model maps it plus in-flight flags to `CatalogPhase`. Browse and search each keep their own `CatalogListState` in memory for the current screen's lifetime, which is how clearing a search restores the browse list instantly. This is screen state, not a cache: it's never persisted or shared.

## 9. Persistence

- Only saved-product snapshots are persisted (`Application Support/saved-products.json`, versioned envelope `{ "version": 1, "items": [...] }`).
- `FileSavedProductsRepository` reads once at launch and writes atomically on change through an actor, off the main thread.
- A file that fails to decode is renamed `saved-products.corrupt-<timestamp>.json` and logged at `.error`; the app continues with an empty list.
- `SavedProductsStore` (`@MainActor @Observable`) is the in-memory source of truth every screen observes, which keeps state consistent everywhere without notifications.
- Installation ID, session bookkeeping and experiment assignments live in `UserDefaults` (small, non-sensitive). See [Analytics.md § 2](Analytics.md#2-identity-sessions-and-user-properties).

## 10. Logging and observability

`Log` exposes one `Logger` per category; subsystem = bundle identifier.

| Category | Content | Level |
|---|---|---|
| `lifecycle` | launch, scene phase, session start | info |
| `navigation` | route pushes/pops, tab changes | debug |
| `network` | method, sanitized URL, request id, status, latency, size, error, cancellation | debug (success) / error (failure) |
| `analytics` | every event with properties; user-property changes | debug |
| `experiment` | assignment, override, exposure (first and suppressed duplicates) | info |
| `persistence` | saved-items load/save, corrupt-file quarantine | info / error |
| `performance` | first-page latency, time to first content | info |

There is no `cache` category (no caching) and no `image` category: `AsyncImage` exposes no load lifecycle hooks, so image start and cancel are verified manually ([Networking.md § 4](Networking.md#4-image-loading)).

Rules: search terms and product titles are interpolated with `privacy: .private` (redacted outside a debugger); status codes, ids and durations are `.public`. No tokens or full payloads are logged. `debug` messages aren't persisted by the system by default, which keeps production noise low. The DEBUG Diagnostics panel reads `OSLogStore(scope: .currentProcessIdentifier)` to show recent entries in-app.

**Analytics vs logs:** analytics events describe meaningful user behavior and outcomes: low volume, stable schema, documented in Analytics.md. Logs describe technical behavior: high volume, free-form, for debugging. A network request is logged, never tracked as an analytics event.

## 11. Testing and verification

- **TDD (Red → Green → Refactor)** for all testable behavior. Each stage lists the tests to write first in [ImplementationPlan.md](ImplementationPlan.md).
- **Swift Testing** (`@Test`, `#expect`, parameterized arguments). Tests are deterministic: no live network, injected clocks, controllable fakes (fake repositories that suspend until the test resumes them, to test out-of-order completion).
- **HTTP layer:** `StubURLProtocol` on an ephemeral `URLSessionConfiguration` tests request building, status mapping, decoding and cancellation of `URLSessionAPIClient`.
- **Source-scan tests:** `NavigationRuleTests` (the navigation rule) and `TaxonomyDocumentationTests` (Active events in Analytics.md == `AnalyticsEvent` cases).
- **Agent verification = `xcodebuild build` + `xcodebuild test` only.** The agent does not run or drive the app in the Simulator (token cost). Each stage lists **manual Simulator checks for the developer**, and their results are recorded in the review log.
- **What unit tests can't prove:** `AsyncImage`'s network cancellation. It's checked manually ([Networking.md § 4](Networking.md#verification)) and never claimed from unit tests.
- **Excluded:** UI snapshot tests (spec exclusion).

## 12. Known trade-offs

- **Xcode 26.0 instead of the current Xcode release (27.2).** The developer's machine can't be updated within the assignment window (Xcode 27.2 needs a macOS update). Risk: a reviewer on Xcode 27.x opens a project last built with 26.0. That is normally forward-compatible, but unverified. Mitigation: no deprecated APIs, no Xcode-version-specific build settings, re-verify after updating.
- **No caching.** The catalog needs a network connection, and thumbnails re-download on reappearance (~10 KB each). This was accepted to keep the scope focused.
- **`AsyncImage`:** no request de-duplication and no downsampling control; cancellation is expected rather than proven.
- **`ServiceContainer` resolves at runtime,** so a missing registration is a crash rather than a compile error. The registration test mitigates this. The `forceResolve` trap itself is not unit-tested: Swift Testing exit tests aren't supported on iOS.
- **Full master-spec scope** exceeds the brief's suggested effort. It was chosen deliberately to demonstrate product instrumentation and experimentation.
