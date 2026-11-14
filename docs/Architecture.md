# Architecture — MerchantCatalog

**Status:** Approved by the developer (2026-11-13). Written as the target design and updated by each stage; as of release 1.0 (S7) it describes the app as built.

## 1. Summary

| Concern | Choice | Alternative considered |
|---|---|---|
| UI | SwiftUI, iOS 26.0 minimum, Xcode 26.0; universal app (iPhone + iPad) with the phone layout on iPad | UIKit: no benefit for this scope |
| Pattern | Clean Architecture + MVVM, feature folders with `Domain` / `Data` / `Presentation` | TCA: used by many teams, but not the developer's working knowledge. MVVM with explicit intents is explainable end to end |
| State | `@MainActor @Observable` view models exposing a state value + intent methods | `ObservableObject`/Combine (previous projects): Observation is simpler and tracks only the properties a view reads |
| Concurrency | Swift 6 language mode, strict concurrency, structured async/await | Combine pipelines: more ceremony, weaker cancellation story |
| Infrastructure boundaries | **Protocol-first**: `APIClientType`, `AnalyticsTracking` + `AnalyticsProvider`, repository protocols | Concrete singletons: impossible to swap or fake |
| DI | `ServiceContainer` (register/resolve) configured once at launch; scene **Configurators** resolve services and build view models | Pure init injection from a composition root: compile-time safer. The container is kept for consistency with the developer's established architecture |
| Networking | Moya-style `TargetType` endpoints + `URLSessionAPIClient` (async) | Alamofire: unnecessary dependency |
| Caching | **None**: `urlCache = nil`, every request hits the network | `URLCache` (headers give no freshness; images are `no-store`); custom caches (too much for this scope). See [Networking.md § 3](Networking.md#3-caching--deliberately-not-implemented) |
| Images | `ImageLoading` + `URLSessionImageLoader` (own session, no cache), loaded by `.task(id:)` in `ProductImageView`: starts on appear, SwiftUI cancels it on disappear, which cancels the request (D-78) | `AsyncImage` (used until S7): no way to cancel or observe its request, and it uses `URLSession.shared`. A loader with de-duplication and a cache: more code than this scope needs |
| Navigation | Two tabs, one `NavigationStack` per tab, a `Router` per tab with a `Route` enum | Single root stack around the `TabView`: hides the tab bar on push |
| Persistence | JSON file in Application Support behind a repository protocol (saved snapshots only) | SwiftData: heavier, harder to test, no relational need |
| Logging | `os.Logger` with categories; the DEBUG viewer reads `OSLogStore` | Print-based logger: loses levels, privacy redaction and Console.app integration |
| Tests | Swift Testing, hand-written fakes, `URLProtocol` stub for HTTP | XCTest: fine, but Swift Testing's parameterized tests suit endpoint, sort and taxonomy tables |
| Modules | Single app target with folder boundaries | Local SPM packages: worthwhile once a second app or extension shares code |

## 2. Folder structure

```text
MerchantCatalog/                       # app target (file-system-synchronized groups) — as built, 1.0
  App/
    MerchantCatalogApp.swift           # @main; AppContext.configure(); scenePhase → lifecycle analytics
    AppContext.swift                   # registers concrete services under their protocols
    AppTabView.swift                   # TabView + the ONLY NavigationStacks / navigationDestination
    AppPhase+ScenePhase.swift          # ScenePhase → AppPhase for the lifecycle tracker
  Core/
    DI/            ServiceContainerType.swift, ServiceContainer.swift
    Navigation/    Router.swift, Route.swift, ProductDetailRoute.swift, AppTab.swift, TabSelection.swift
    Logging/       Log.swift (Logger categories), LogStoreReader.swift (OSLogStore reader [DEBUG])
    Time/          Clock+Stopwatch.swift (elapsed time on an injected clock), Duration+Milliseconds.swift
    Analytics/     AnalyticsTracking.swift (protocol), AnalyticsProvider.swift (protocol),
                   AnalyticsEvent.swift, AnalyticsValue.swift, AnalyticsEnvelope.swift,
                   AnalyticsService.swift (AnalyticsTracking impl, fans out),
                   Providers/ (LoggingAnalyticsProvider, InMemoryAnalyticsProvider [DEBUG]),
                   SessionTracker.swift, AppLifecycleTracker.swift (scene phase → lifecycle events),
                   InstallationIDProvider.swift, UserProperty.swift, AppInfo.swift
    Experiments/   Experiment.swift, ExperimentAssigner.swift, ExperimentService.swift (+ DEBUG ExperimentOverrides),
                   LocalExperimentService.swift, ExposureTracker.swift
  Networking/
    APIClientType.swift (protocol), URLSessionAPIClient.swift, TargetType.swift, HTTPMethod.swift,
    APIConfig.swift, AppError.swift, RequestDelay.swift (DEBUG slow-network delay, Mutex), NetworkLogger.swift,
    ImageLoading.swift (protocol), URLSessionImageLoader.swift (cancellable, no cache) [S7],
    NetworkLogFormatter.swift (DEBUG: full request/response log lines) [S7]
  Shared/
    Products/
      Domain/      Product (+ ProductAvailability), ProductSummary (a list item) [S7], ProductPage, ProductSort,
                   ProductRepository (protocol), ProductInsights (facts builder)
      Data/        ProductsTarget, ProductDTO + ProductSummaryDTO (+ mapping), LiveProductRepository
    Saved/
      Domain/      SavedProduct (snapshot: a ProductSummary + savedAt, D-82), SavedProductsRepository (protocol)
      Data/        FileSavedProductsRepository (atomic writes, corrupt-file quarantine)
      SavedProductsStore.swift         # @MainActor @Observable source of truth shared by all screens
      SavedProductFormat.swift         # "Price when saved" / saved-date copy
  Features/
    Catalog/
      Domain/      CatalogListState (pure pagination/de-dup state), SearchQuery (trimmed query)
      Presentation/ CatalogView (+ sort menu), CatalogViewModel, CatalogFeed (one list's state),
                    CatalogPhase (+ CatalogFooter, CatalogListContent), CatalogConfigurator, CatalogCopy,
                    CatalogLayout (columns by Dynamic Type) [S7], ProductCardView, ProductCardModel,
                    ProductCardAccessibility (VoiceOver label), ProductSort+Title, CardExperiment
    ProductDetail/
      Presentation/ ProductDetailView (+ sections), ProductDetailViewModel, ProductDetailConfigurator,
                    ProductGalleryView, ProductGalleryModel, ProductDetailHeader, ProductFactRow
    Saved/
      Presentation/ SavedView, SavedViewModel, SavedRowModel, SavedConfigurator
    Diagnostics/                        # compiled in DEBUG only
      Domain/      SlowNetworkSetting (persisted toggle → RequestDelay)
      Presentation/ DiagnosticsView, DiagnosticsViewModel, DiagnosticsConfigurator (events, user
                    properties, experiment override, slow network, logs, reset installation ID)
  DesignSystem/
    Components/    ProductImageView (+ ProductImageModel, ImageLoaderEnvironment: `\.imageLoader`) [S7], ErrorBanner,
                   SaveButton (+ CardSaveButton)
  Assets.xcassets                       # AppIcon (drawn by scripts/make-app-icon.swift), AccentColor
MerchantCatalogTests/
  Fakes/           FakeAPIClient, StubURLProtocol, FakeProductRepository, ProductFixtures,
                   InMemorySavedRepository, SpyAnalytics, SpyAnalyticsProvider, FakeLogReader, FakeImageLoader
  Support/         RepositoryFiles (source scans), IsolatedDefaults, TestNow, TestUUIDs, TestClock (+ tests),
                   ProductJSON, TemporaryDirectory, CardExperiments
  …Tests.swift     mirror the app folders
```

`Shared/` holds domain and data used by more than one feature (products, saved items). A feature folder holds only what that feature uses. Test doubles live in the test target only. DEBUG-only runtime tooling lives in `Features/Diagnostics`.

The tree above is the 1.0 layout as built. Planned items that were never needed (`Core/Persistence/JSONFileStore`, `DesignSystem/Theme`, `ProductQuery`, `SearchDebouncer`, `HTTPStatusCode`) are explained in the stage notes below, which record how it grew.

**What exists (S0):** S0 created `App/` (`MerchantCatalogApp`, `AppContext`, `AppTab`, `AppTabView`), `Core/DI`, `Core/Navigation`, `Core/Logging` and `Assets.xcassets`, the repo-level `scripts/make-app-icon.swift` (not part of the app target), plus tests in `MerchantCatalogTests/App` and `MerchantCatalogTests/Core/{DI,Navigation}`. Every other folder is created together with its first file: git doesn't track empty folders, and a placeholder file inside a file-system-synchronized folder would be copied into the app bundle.

**What exists (S1):** `Core/Analytics` (everything listed above), `Core/Logging/LogStoreReader.swift`, `Features/Diagnostics/Presentation`, `App/AppPhase+ScenePhase.swift`, plus tests in `MerchantCatalogTests/Core/Analytics`, `Features/Diagnostics`, `Fakes` and `Support`.

**What exists (S2):** `Networking/` (all files listed), `Core/Time`, `Shared/Products/{Domain,Data}` (without `ProductQuery`/`ProductInsights`), `Features/Catalog/{Domain,Presentation}` (without `SortMenu`/`SearchDebouncer`), `DesignSystem/Components/{ProductImageView, ErrorBanner}`, `Features/Diagnostics/Domain/SlowNetworkSetting`, plus tests in `MerchantCatalogTests/{Networking, Shared/Products, Features/Catalog, Core/Time}`. There is no `HTTPStatusCode` type: the status mapping is a small switch in `URLSessionAPIClient`. `DesignSystem/Theme` isn't needed yet (system styles only).

**What exists (S3):** `Features/Catalog/Domain/SearchQuery`, `Features/Catalog/Presentation/{CatalogFeed, ProductSort+Title}` (the sort menu is a private view in `CatalogView.swift`), `ProductsTarget.search` and `ProductRepository.search`, plus tests in `MerchantCatalogTests/Features/Catalog/{CatalogViewModelSearchTests, CatalogViewModelSortTests, SearchQueryTests, ProductSortTitleTests}`, `Core/Analytics/SearchAnalyticsEventTests` and `Support/TestClockTests`. The target layout's `ProductQuery` and `SearchDebouncer` weren't needed: only the catalog uses the trimmed query, so `SearchQuery` lives in the feature, and the debounce is a sleep on the injected clock inside the view model's search task.

**What exists (S5):** `Shared/Saved/Domain/{SavedProduct, SavedProductsRepository}`, `Shared/Saved/Data/FileSavedProductsRepository`, `Shared/Saved/{SavedProductsStore, SavedProductFormat}`, `Core/Navigation/TabSelection` (and `AppTab`, moved from `App/` because features now depend on it), `Features/Saved/Presentation/{SavedView, SavedViewModel, SavedRowModel, SavedConfigurator}`, `DesignSystem/Components/SaveButton`, `ProductsTarget.detail` and `ProductRepository.product(id:)`, plus tests in `MerchantCatalogTests/{Shared/Saved, Features/Saved}`, `Features/Catalog/CatalogViewModelSaveTests`, `Features/ProductDetail/ProductDetailSavedTests`, `Core/Analytics/SavedAnalyticsEventTests`, `Core/Navigation/TabSelectionTests`, `Fakes/InMemorySavedRepository` and `Support/TemporaryDirectory`. There is no `Core/Persistence/JSONFileStore`: one file type doesn't need a generic store, so `FileSavedProductsRepository` writes and quarantines its own file.

**What exists (S6):** `Core/Experiments/{Experiment, ExperimentAssigner, ExperimentService, LocalExperimentService, ExposureTracker}` (`ExperimentService.swift` also declares the DEBUG-only `ExperimentOverrides`), `Features/Catalog/Presentation/CardExperiment`, plus tests in `MerchantCatalogTests/Core/Experiments`, `Features/Catalog/CatalogViewModelExperimentTests` and `Support/CardExperiments` (`unobservedCardExperiment()` for catalog suites that don't look at the experiment). The Diagnostics override lives in the existing Diagnostics files.

**What exists (S7):** `Features/Catalog/Presentation/CatalogLayout` (two grid columns, one at accessibility text sizes, D-75), plus `MerchantCatalogTests/Features/Catalog/CatalogLayoutTests`. Larger tap targets (D-76) changed only view code. At the developer's request at the S7 gate, `AsyncImage` was replaced (D-78): `Networking/{ImageLoading, URLSessionImageLoader}`, `DesignSystem/Components/{ProductImageModel, ImageLoaderEnvironment}`, plus `MerchantCatalogTests/Networking/URLSessionImageLoaderTests`, `DesignSystem/ProductImageModelTests` and `Fakes/FakeImageLoader`. At the developer's request (D-81), list pages carry `ProductSummary` items (`Shared/Products/Domain/ProductSummary`, `ProductSummaryDTO`, `select` on list and search targets) and details load `/products/{id}` on every route; tests in `MerchantCatalogTests/Shared/Products/ProductSummaryTests`. D-83 replaced the route enum with `ProductDetailRoute { productID, source }`; `ProductDetailViewModel` gained `DetailLoadState`/`DetailScreen`.

**What exists (S4):** `Core/Navigation/ProductDetailRoute`, `Shared/Products/Domain/ProductInsights` (and the details fields on `Product`, with `ProductDimensions` and `ProductReview`), `Features/ProductDetail/Presentation` as listed above, plus tests in `MerchantCatalogTests/Shared/Products/ProductInsightsTests`, `MerchantCatalogTests/Features/ProductDetail/` and `MerchantCatalogTests/Features/Catalog/CatalogViewModelSelectionTests`. The At a Glance chips are a private view in `ProductDetailView.swift`; `ProductFactRow` turns each `ProductInsights.Fact` into a label, value and symbol. `ProductsTarget.detail` isn't needed yet (S5).

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
| Analytics (destinations) | `AnalyticsProvider`: `send(_: AnalyticsEnvelope)`, `userPropertyDidChange(_: UserPropertyChange)` | `LoggingAnalyticsProvider`, `InMemoryAnalyticsProvider` (DEBUG) | Add e.g. an Amplitude/Firebase provider type and pass it to `AnalyticsService` in `AppContext`. No change to `AnalyticsTracking`, events or view models |
| Images | `ImageLoading`: `image(from:)` | `URLSessionImageLoader` (own `URLSession`, no cache, cancellable) | Registered in `AppContext` and put into the SwiftUI environment (`\.imageLoader`) by `MerchantCatalogApp`; `ProductImageView` reads it there (D-78) |
| Products | `ProductRepository` | `LiveProductRepository` | — |
| Saved items | `SavedProductsRepository` | `FileSavedProductsRepository` | — |
| Experiments | `ExperimentService`: `assignment(for:)`, resolved once per launch (D-69); DEBUG `ExperimentOverrides` for Diagnostics | `LocalExperimentService` (SHA-256 bucketing, assignment stored in `UserDefaults`) | A remote-config implementation later |

Rules: services are registered in the container **as their protocol type**; view models and repositories receive protocols through their initializers; only `AppContext` names concrete types. Tests prove the swap: `AnalyticsService` delivers every event to every registered provider (spy providers), and repositories run against `FakeAPIClient`.

## 5. Concurrency model

- **Swift 6 language mode with complete strict-concurrency checking.** Zero warnings is a review requirement. Before each stage, confirm the project's Swift version, deployment target and concurrency settings.
- **Build settings** (verified 2026-11-13 in S0 with `xcodebuild -showBuildSettings`): `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0` on both targets. `SWIFT_DEFAULT_ACTOR_ISOLATION` and `SWIFT_APPROACHABLE_CONCURRENCY` are deliberately not set, although Xcode 26 templates usually enable them: code is nonisolated by default, and `@MainActor` is written explicitly on the UI-facing types listed below.
- **Structured first.** Work starts from SwiftUI's `.task`/`.refreshable` or from async view-model intents, so cancellation follows the view lifecycle automatically. Unstructured `Task { }` is used only where a synchronous UI callback must start async work (e.g. a button tap or text change); the view model keeps the handle and cancels it on supersession or teardown.
- **Explicit isolation.** `@MainActor` on UI-facing types only: view models, routers, `SavedProductsStore`, `ServiceContainer`, `ExposureTracker`, `LocalExperimentService` (it sets a user property and reads `InstallationIDProvider`), and the analytics stack (`AnalyticsTracking`, `AnalyticsProvider`, `AnalyticsService`, `SessionTracker`, `InstallationIDProvider`, `AppLifecycleTracker`; D-33). Analytics is main-actor and synchronous because every caller is main-actor UI code: event order and sequence numbers stay deterministic, with no unstructured tasks. A future vendor provider hands work to its SDK's own queue. The DEBUG `OSLogStoreReader` reads the log store in a `@concurrent` function, off the main actor. Domain models and DTOs are `Sendable` value types. `URLSessionAPIClient` and repositories are `Sendable` (immutable configuration). File writes go through an **actor**. No `@unchecked Sendable` or `nonisolated(unsafe)` without a justifying comment.
- **Cancellation propagates.** `URLSession`'s async API cancels the network task when the Swift task is cancelled. `CancellationError` / `URLError.cancelled` means "no state change", never an error UI.
- **Clock:** `CatalogViewModel` takes an injected `any Clock<Duration>` (`ContinuousClock` in the app, the hand-written `TestClock` in tests). Load durations (`duration_ms`) come from it (D-40), measured with `clock.stopwatch()`; the search debounce sleeps on it (`searchDebounce`, 300 ms). `TestClock.sleep` suspends until a test advances the clock past the deadline and throws `CancellationError` when its task is cancelled; `waitForSleepers(_:)` lets a test advance only once the debounce is sleeping, so timing tests stay deterministic. Sessions keep the wall clock (D-35).
- **Images (S7, D-78):** `ProductImageView` loads in `.task(id: url)`, so SwiftUI owns the task: cancelled on disappear or a URL change. `URLSessionImageLoader.image(from:)` is `@concurrent` (download and decoding off the main actor) and awaits `URLSession.data(for:)`, so the cancellation cancels the request; `ProductImageModel` (`@MainActor @Observable`) ignores a result that arrives after cancellation.
- **Networking off the main actor:** `URLSessionAPIClient.request` and `LiveProductRepository.products` are `@concurrent`, so request building, decoding and DTO mapping never run on the main actor; the view model awaits the `Sendable` `ProductPage`. The DEBUG slow-network delay is a `RequestDelay` (`Mutex`), written on the main actor and read by the client.
- **View-model tasks:** browse page 1 loads from the view's `.task` (cancelled with the view; the next appearance loads again). Everything else starts from synchronous callbacks, so the view model keeps the handles (D-52): `firstPageTask` (browse Retry, Reload, sort change), `searchTask` (search page 1: the debounce sleep, then the request; a keystroke, Retry or sort change replaces it) and one page ≥ 2 task per list. A new page 1 or a refresh cancels that list's page task. Each task runs the request through a static helper that doesn't reference the view model and applies the result through `[weak self]`, so a request never keeps the view model alive; its `isolated deinit` cancels all of them, so no request or analytics event outlives the screen. A hidden list's in-flight load finishes in the background and updates only that list.
- **Details load (S5; every route since D-81):** details fetch `/products/{id}` from the view's `.task` (`ProductDetailViewModel.start()`): from Saved over the snapshot, from the catalog or search over the list item's summary; so leaving the screen cancels it and the next appearance tries again; the banner's Retry starts from a tap, so the view model keeps that task (`retryTask`), runs the request through a static helper and applies the result through `[weak self]`; its `isolated deinit` cancels it. Cancellation leaves the screen as it was (the skeleton, or Saved's snapshot after a failure) with no event. Since D-83 a cancelled Retry returns to the failure it started from, and from Saved the snapshot stays on screen while a Retry runs.
- **Stale-response protection:** every page-1 load stamps its list (`CatalogFeed`) with a new number from one monotonically increasing counter; page ≥ 2 loads carry the stamp they started with. A result whose list no longer has that stamp, or no longer exists (search cleared), is dropped even if cancellation lost the race. A new query gets a new list, so an earlier query's response can never land on it (AC-S2). After the debounce sleep, the task checks `Task.isCancelled`: a keystroke may cancel it after the sleep ended but before it ran.
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

- `AppContext.configure(defaults:appInfo:)` runs once at launch and registers, by protocol: `APIClientType`, `ImageLoading` (also exposed as `imageLoader` for the environment, D-78), `ProductRepository`, `SavedProductsRepository`, `AnalyticsTracking`, `ExperimentService`, plus `SavedProductsStore`, `SessionTracker`, `InstallationIDProvider`, and in DEBUG `InMemoryAnalyticsProvider` and `LogReading`. **S1 state:** the analytics services are registered; it also sets the launch user properties and exposes `lifecycle` (`AppLifecycleTracker`), which `MerchantCatalogApp` feeds with `scenePhase` changes (`onChange(of:initial: true)`, app-wide phase). Tests pass an isolated `UserDefaults` suite. Each call returns a new `AppContext` with a new container; the app keeps the one built at launch. There is no global singleton, and every test gets an isolated container.
- `ServiceContainer` keys services by `ObjectIdentifier(T.self)`, the exact registered type. `String(describing:)` keys collide for same-named types in different scopes; an S0 test showed this.
- Each scene has a **Configurator** that resolves services and builds the view model with **init injection**. View models never touch the container, so unit tests construct them directly with fakes. `make(...)` returns the screen, which owns its view model in `@State` (`CatalogConfigurator.make(from:isTabSelected:)`, `DiagnosticsConfigurator.make(from:)`). `AppTabView` owns only the tab selection, the routers and the sheet flag, never a feature's view model; it passes the Catalog screen `isTabSelected` for `catalog_viewed` (D-39). Its body re-runs the Configurator on each update; `@State` keeps the first view model, and the extra ones are discarded unused (view-model initializers have no side effects).
- **Registration guard** (developer's choice, 2026-11-13): each Configurator resolves its services in `static func resolveDependencies(from: any ServiceContainerType) -> Dependencies?`, which returns `nil` if anything is missing, and its `make(...)` uses the same function. `AppContextRegistrationTests` calls every Configurator's `resolveDependencies(from:)` against `AppContext.configure().container`, so a missing registration fails a test instead of crashing in `forceResolve`. Cases: `DiagnosticsConfigurator` (S1, DEBUG), `CatalogConfigurator` (S2), `ProductDetailConfigurator` (S4) and `SavedConfigurator` (S5). **S6:** `AppContext` registers `LocalExperimentService` as `any ExperimentService` (and, in DEBUG, `any ExperimentOverrides`), resolves every experiment at launch (setting `experiment_assignments`, D-69) and registers `ExposureTracker`. `CatalogConfigurator` resolves both and builds a `CardExperiment` value (the launch assignment + the tracker) for `CatalogViewModel` (D-70); `DiagnosticsConfigurator` resolves the service and the overrides. **S5:** `AppContext` registers one `FileSavedProductsRepository` (Application Support) as `any SavedProductsRepository` and `SavedProductsStore` over that same instance (S5 review finding 2; `configure(savedProductsDirectory:)` for tests) and exposes it as `savedProducts`: `MerchantCatalogApp` loads it from the root view's `.task` and passes it to `AppTabView` for the Saved badge. `SavedConfigurator.make(from:router:tabs:isTabSelected:)` gets the Saved tab's router and the `TabSelection` (D-61). **S4:** `CatalogConfigurator.make(from:router:isTabSelected:)` also takes the Catalog tab's `Router`, which `AppTabView` owns, and injects it into `CatalogViewModel` (D-53). **S2 state:** `AppContext` also registers `URLSessionAPIClient` as `any APIClientType`, `LiveProductRepository` as `any ProductRepository`, and in DEBUG `SlowNetworkSetting`, which shares the client's `RequestDelay`.

## 7. Navigation

```swift
enum Route: Hashable {
    case productDetail(ProductDetailRoute)   // { productID, source } (D-83)
}

@MainActor @Observable
final class Router {
    var path: [Route] = []
    func push(_ route: Route)
    func showProductDetail(_ route: ProductDetailRoute)
    func pop()
    func popToRoot()
}
```

- **S0 state:** `Route` had one placeholder case, `productDetail(productID: Int)`, with a text placeholder destination. The S0 `Router` API is `path`, `push(_:)`, `pop()` and `popToRoot()`; both pops do nothing at the root.
- **As built (S4):** `Route.productDetail(ProductDetailRoute)`, where `ProductDetailRoute` holds the list's `Product` (now `Hashable`) and the `source` (`catalog` / `search`); S5 extends it for Saved (D-57). `Router.showProductDetail(_:)` pushes it; the `navigation` log names only the product id and source (`Route.logDescription`), never a title. `CatalogViewModel` gets the Catalog tab's router by injection (D-53): a card tap calls `cardSelected(id:in:)`, which tracks `product_selected` from the list on screen and pushes the route; cards of the hidden browse layer are ignored. While a route is on the Catalog stack, `searchDismissed()` is ignored (D-54). The destination is `ProductDetailConfigurator.make(from:route:)`; the screen owns its `ProductDetailViewModel` in `@State`, which sends `product_details_viewed` once (one view model per push) and `product_gallery_interacted` once per visit (D-59). Details needed no request then: list items were full products (Networking.md A7); since D-81 list items are summaries and details load `/products/{id}`.
- **As built (S5; D-81):** `ProductDetailRoute` is an enum (D-62): `.list(ProductSummary, source:)` from the browse grid or search results (the list item, since D-81), `.saved(SavedProduct)` from the Saved list, with `productID` and `source` (`saved` for the second). A Saved row pushes `.saved(snapshot)` on the Saved tab's stack. `TabSelection` (`@MainActor @Observable`) holds the selected `AppTab`; `AppTabView` owns it, binds the tab view to it and injects it into `SavedViewModel`, whose empty state's Browse catalog calls `tabs.select(.catalog)` (D-61).
- **As built (D-83, S7):** `ProductDetailRoute` is `struct { productID, source }` for every source; the catalog and the Saved list push it. `ProductDetailViewModel` loads `/products/{id}` and exposes `screen` (`skeleton` | `content(Product)` | `failed(AppError)`) and `load` (`DetailLoadState`); from Saved it reads the snapshot from `SavedProductsStore` by id at init and shows it when the request fails. `ProductDetailView` lays out `Product.detailPlaceholder`, redacted and pulsing, as the skeleton.
- One `Router` per tab, owned by `AppTabView`. `AppTabView` hosts the two `NavigationStack(path:)` and the single `navigationDestination(for: Route.self)` switch that calls Configurators.
- **Navigation rule** (enforced by `NavigationRuleTests`, a source scan): `NavigationStack` and `navigationDestination` appear only in `App/AppTabView.swift`; `NavigationLink` and `NavigationView` appear nowhere. Feature views request navigation through view-model intents that call the router.
- Tab switching (e.g. the Saved empty state's "Browse catalog") goes through an `@Observable` tab selection owned by `AppTabView`.

## 8. Presentation state

Each list screen uses an explicit state value rather than loose booleans:

```swift
enum CatalogPhase: Equatable {
    case initialLoading
    case content(footer: CatalogFooter, refreshError: AppError?)
    case empty                      // browse, 0 products
    case noResults(query: String)   // search, 0 products (S3)
    case failed(AppError)
}

enum CatalogFooter: Equatable { case idle, loading, failed(AppError), end }
```

**As built (S3):** the view model holds two `CatalogFeed` values, browse and (while a query is committed) search. A feed owns its `CatalogListState`, cards, sort, generation stamp, first-page and page-load status and refresh error, and maps them to its `CatalogPhase`; the view model runs the requests and analytics. `phase`, `cards`, `sort` and `listContext` describe the list on screen (search if present, else browse). `CatalogPhase` gains `noResults(query:)`. Each page-1 load (not a refresh) gives the list a new `listID`, and the view keys the grid by it, so a sort change or a new query shows the new list from the top (S3 review finding 2). The view renders `browseList` and `searchList` (`CatalogListContent`: phase + cards) as two layers; the browse layer stays in the hierarchy, invisible and inert, while search results show (D-47).

`CatalogListState` (Domain) is a pure struct owning the items, the `id` set for de-duplication, `total`, the next `skip` (the raw count received, so dropped duplicates don't shift it), and `canLoadMore` (false after an empty page, so an inconsistent response can't loop). The view model maps it plus its first-page status, page-load status and refresh error to `CatalogPhase`. The system refresh control shows a pull-to-refresh, so "refreshing" isn't part of the phase. Browse and search each keep their own `CatalogListState` in memory for the current screen's lifetime, which is how clearing a search restores the browse list instantly. This is screen state, not a cache: it's never persisted or shared.

## 9. Persistence

- Only saved-product snapshots are persisted (`Application Support/saved-products.json`, versioned envelope `{ "version": 1, "items": [...] }`).
- `FileSavedProductsRepository` reads once at launch and writes atomically on change through an actor, off the main thread.
- A file that fails to decode is renamed `saved-products.corrupt-<timestamp>.json` and logged at `.error`; the app continues with an empty list.
- `SavedProductsStore` (`@MainActor @Observable`) is the in-memory source of truth every screen observes, which keeps state consistent everywhere without notifications.
- **As built (S5):** the file is `{ "version": 1, "items": [{ id, title, thumbnailURL, price, rating, category, savedAt }] }` with the price as a decimal string and `savedAt` as ISO 8601 with milliseconds, so both round-trip exactly. Invalid JSON is moved to `saved-products.corrupt-<yyyyMMdd'T'HHmmss'Z'>.json`; an unknown `version` is left in place (D-65); both log `.error` and load an empty list. The repository never throws: storage problems are logged. The store loads once from the root view's `.task`; a save made before that finishes is kept and merged (D-66). Each later change writes the whole list in a task chained after the previous write (a tap starts it, so it is unstructured; the store keeps the handle), so the file always ends with the latest list. `save`/`remove` return a `SavedProductsChange` (snapshot, `saved_duration_s`, count after), from which view models build `product_saved` / `product_unsaved` with their surface; the store sets `saved_products_count`.
- **Since D-82 (S7):** `SavedProduct` is `{ summary: ProductSummary, savedAt }`, the same summary a list item has (since D-83 details open by id and find the snapshot in the store). The file keeps the flat version-1 fields above; `FileSavedProductsRepository` maps them to and from the summary, so files written before D-82 load unchanged (tested).
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

Analytics events are logged at debug level by `LoggingAnalyticsProvider` (`event <name> #<sequence> session <id> {properties}`; user properties as `old → new`), visible in Console.app with debug messages included.

There is no `cache` category (no caching). Image requests log to `network` too (DEBUG: one line when each ends, e.g. `[<id>] GET <url> → cancelled after 12 ms`), which makes cancellation on fast scrolling visible in Console.app ([Networking.md § 4](Networking.md#verification)).

In Release, `NetworkLogger` writes one line when a request starts (`[<id>] GET <url>`) and one when it ends (`[<id>] 200 in 312 ms, 48213 bytes`, `[<id>] failed after … ms: <error> (<cause>)` or `[<id>] cancelled after … ms`). The `q` value is replaced by `<private>` before logging, so the URL itself is logged as public. Errors are logged only as a summary (`URLError -1009`, `DecodingError.typeMismatch at products.0.price`, or a type name), never as their description, which can contain the full request URL. `CatalogViewModel` logs first-page latency to `performance` (info).

**DEBUG extended network logging (S7, D-80):** DEBUG builds replace those lines with every field of each request, framed so a request reads as a unit:

```text
┌──── → REQUEST [c309e10f] ────
│ GET https://dummyjson.com/products?limit=20&skip=0
│ Query    limit=20, skip=0
│ Headers  none set by the app (URLSession adds its defaults when sending)
│ Timeout  60 s
│ Body     none
└────────────────────────────────────────
┌──── ← RESPONSE [c309e10f] 200 · 34 ms ────
│ application/json · 48213 bytes
│ Headers
│   Content-Type: application/json; charset=utf-8
│   …
│ Body
│ {
│   "limit" : 20,
│   …
└────────────────────────────────────────
```

API requests log the REQUEST box at the start and the RESPONSE box at the end (other requests may log in between); a request without a usable response ends with a closing box (`← RESPONSE [<id>] cancelled after 12 ms`, `failed after …`). Image requests log one line when they end (`[<id>] GET <url> → 200 · 34 ms · 63250 bytes image/webp`, or `→ cancelled after 12 ms`), so scrolling stays readable. JSON bodies are pretty-printed with sorted keys; binary bodies are logged only by size and type. The unified log cuts a message at about 1 KB (measured 2026-11-14 on macOS with `log show` and `log stream`: longer messages kept 1,005 payload characters), so a box is split at line breaks into messages of at most 800 UTF-8 bytes, each line starting with the frame. Redacted: the search term (`q=<private>`, D-18), credential headers (`Authorization`, `Cookie`, `Set-Cookie`, …) and every JSON value under a key containing "email" (reviewer emails, ProductSpecification § 4.3). `URLSession`'s own default request headers (e.g. `User-Agent`) are added when sending and don't appear. `NetworkLogFormatter` is compiled only in DEBUG (unit-tested in `NetworkLogFormatterTests`).

Rules: search terms and product titles are interpolated with `privacy: .private` (redacted outside a debugger); status codes, ids and durations are `.public`. Release builds log no tokens and no payloads; DEBUG builds log payloads only as described above. `debug` messages aren't persisted by the system by default, which keeps production noise low. The DEBUG Diagnostics panel reads `OSLogStore(scope: .currentProcessIdentifier)` to show the app subsystem's entries from the last hour (newest 200). Expected, not verified by a test: debug-level entries are normally not kept, so `analytics` and `navigation` lines may be missing there; the Diagnostics event log (from `InMemoryAnalyticsProvider`) and Console.app show them.

**Analytics vs logs:** analytics events describe meaningful user behavior and outcomes: low volume, stable schema, documented in Analytics.md. Logs describe technical behavior: high volume, free-form, for debugging. A network request is logged, never tracked as an analytics event.

## 11. Testing and verification

- **TDD (Red → Green → Refactor)** for all testable behavior. Each stage lists the tests to write first in [ImplementationPlan.md](ImplementationPlan.md).
- **Swift Testing** (`@Test`, `#expect`, parameterized arguments). Tests are deterministic: no live network, injected clocks, controllable fakes (fake repositories that suspend until the test resumes them, to test out-of-order completion).
- **HTTP layer:** `StubURLProtocol` on an ephemeral `URLSessionConfiguration` tests request building, status mapping, decoding and cancellation of `URLSessionAPIClient`.
- **Pure presentation rules** are tested without views: card models, the card's VoiceOver label (`ProductCardAccessibilityTests`), copy, and the grid's column count by Dynamic Type size (`CatalogLayoutTests`). How SwiftUI renders them (layout, hit areas, VoiceOver focus, dark mode) is checked manually.
- **Source-scan tests:** `NavigationRuleTests` (the navigation rule) and `TaxonomyDocumentationTests` (Active events in Analytics.md == `AnalyticsEvent` cases; since 1.0 every event is Active and removed events stay out of code).
- **Agent verification = `xcodebuild build` + `xcodebuild test` only.** The agent does not run or drive the app in the Simulator (token cost). Each stage lists **manual Simulator checks for the developer**, and their results are recorded in the review log.
- **Image cancellation:** unit tests prove that cancelling the loading task stops the `URLSession` load (`StubURLProtocol` sees `stopLoading`) and that the model drops late results. That SwiftUI cancels `.task` when a cell disappears is Apple-documented behavior, checked manually ([Networking.md § 4](Networking.md#verification)).
- **Excluded:** UI snapshot tests (spec exclusion).

## 12. Known trade-offs

- **Xcode 26.0 instead of the current Xcode release (27.2).** The developer's machine can't be updated within the assignment window (Xcode 27.2 needs a macOS update). Risk: a reviewer on Xcode 27.x opens a project last built with 26.0. That is normally forward-compatible, but unverified. Mitigation: no deprecated APIs, no Xcode-version-specific build settings, re-verify after updating.
- **No caching.** The catalog needs a network connection, and thumbnails re-download on reappearance (~10 KB each). This was accepted to keep the scope focused.
- **Images:** no request de-duplication and no downsampling; a reappearing image downloads again (no cache).
- **`ServiceContainer` resolves at runtime,** so a missing registration is a crash rather than a compile error. The registration test mitigates this. The `forceResolve` trap itself is not unit-tested: Swift Testing exit tests aren't supported on iOS.
- **Full master-spec scope** exceeds the brief's suggested effort. It was chosen deliberately to demonstrate product instrumentation and experimentation.
