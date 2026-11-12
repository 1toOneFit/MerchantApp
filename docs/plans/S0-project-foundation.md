# S0 — Project Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A buildable, testable SwiftUI shell (`MerchantCatalog`) with DI container, per-tab routers, a two-tab root and logging categories that every later stage plugs into.

**Architecture:** Single app target + Swift Testing target in an Xcode 26.0 project with file-system-synchronized folders. `AppContext` builds a `ServiceContainer` at launch; `AppTabView` owns one `Router` and one `NavigationStack` per tab. All UI-facing types are explicitly `@MainActor`; no default actor isolation.

**Tech Stack:** Xcode 26.0, Swift 6.2 compiler in Swift 6 language mode, SwiftUI (iOS 26.0), Observation, `os.Logger`, Swift Testing. No packages.

**Spec:** [ImplementationPlan.md § S0](../ImplementationPlan.md#s0--project-foundation), [Architecture.md § 2, § 5, § 6, § 7, § 10](../Architecture.md).

## Global Constraints

- Neutral naming only: `MerchantCatalog`; bundle id `com.example.MerchantCatalog`, tests `com.example.MerchantCatalogTests`.
- `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete` on both targets.
- `SWIFT_DEFAULT_ACTOR_ISOLATION` and `SWIFT_APPROACHABLE_CONCURRENCY` are **not** set: isolation stays explicit (`@MainActor` on UI-facing types only, Architecture § 5).
- `TARGETED_DEVICE_FAMILY = 1` (iPhone; iPad layouts are a deliberate exclusion in ProductSpecification § 8).
- No third-party dependencies, no caching, no `NavigationLink`/`NavigationView`.
- Verify with `xcodebuild build` (0 warnings) and `xcodebuild test` on `platform=iOS Simulator,name=iPhone 17,OS=26.0` only. Never launch or drive the app in the Simulator.

## Decisions taken in this plan

| Decision | Why |
|---|---|
| `ServiceContainer` keys by `ObjectIdentifier(T.self)`, not `String(describing:)` | Two types with the same name in different scopes would collide as strings. |
| `AppContext.configure()` returns a new `AppContext` each call; the `App` holds the one used at runtime | No global mutable singleton; each test gets an isolated container. |
| Registration guard (developer's choice, 2026-11-13): every Configurator exposes `static func resolveDependencies(from: any ServiceContainerType) -> Dependencies?`, used by its `make(...)`; `AppContextRegistrationTests` calls it against `AppContext.configure().container` | Test is tied to the real resolution code; no separate list to drift. S0 has no Configurator, so S0 ships the suite with the container-isolation check; S2 adds the first real case. |
| `Route` has one case in S0: `productDetail(productID: Int)` | An uninhabited enum can't be pushed, so the router would be untestable. S4 replaces the payload with `ProductDetailRoute`. Its S0 destination is a plain text placeholder. |
| Router API: `path`, `push(_:)`, `pop()`, `popToRoot()` | The plan's tests name push/pop/popToRoot; `showProductDetail(_:)` arrives with its view-model intent in S4. |
| Folders are created when their first file lands; no `.gitkeep` | Git can't track empty folders, and a placeholder file inside a synchronized group would be copied into the app bundle. |
| Shared scheme `MerchantCatalog` committed, test target `parallelizable = NO` | Reviewers get a working scheme on clone; no simulator clones during headless test runs. |

## Review Focus

1. **Navigation scan that scans nothing passes vacuously** → `NavigationRuleTests` asserts it found Swift files and that `App/AppTabView.swift` itself contains `NavigationStack` (positive control).
2. **Same-named types in different scopes collide in the container** → `ServiceContainerTests.sameNamedTypesInDifferentScopesDoNotCollide`.
3. **Registering a concrete instance under its protocol, then resolving the concrete type** returns `nil` (key is the declared type) → `ServiceContainerTests.resolvesOnlyUnderTheRegisteredType`.
4. **`pop()` / `popToRoot()` on an empty path** must not crash → `RouterTests.popOnEmptyPathIsNoOp`, `popToRootOnEmptyPathIsNoOp`.
5. **State leaking between `AppContext` instances** (tests sharing a container) → `AppContextRegistrationTests.configureBuildsAnIndependentContainer`.

---

### Task 1: Xcode project skeleton

**Files:**
- Create: `.gitignore`
- Create: `MerchantCatalog.xcodeproj/project.pbxproj` (objectVersion 77, `PBXFileSystemSynchronizedRootGroup` for `MerchantCatalog/` and `MerchantCatalogTests/`)
- Create: `MerchantCatalog.xcodeproj/xcshareddata/xcschemes/MerchantCatalog.xcscheme`
- Create: `MerchantCatalog/App/MerchantCatalogApp.swift` (temporary `WindowGroup { Text("MerchantCatalog") }`)
- Create: `MerchantCatalog/Assets.xcassets` (`AppIcon`, `AccentColor`, `Contents.json`)

**Interfaces:** Produces the `MerchantCatalog` scheme, app target `MerchantCatalog`, test target `MerchantCatalogTests` (`TEST_HOST` = app, `@testable import MerchantCatalog`).

- [ ] **Step 1:** Write `.gitignore` (xcuserdata, DerivedData, build, `*.xcresult`, `.DS_Store`, `.swiftpm`, `.build`).
- [ ] **Step 2:** Write the project, scheme, app entry point and asset catalog.
- [ ] **Step 3:** Run `xcodebuild … build` → `** BUILD SUCCEEDED **`, 0 warnings.
- [ ] **Step 4:** Run `xcodebuild -showBuildSettings -target MerchantCatalog` and `-target MerchantCatalogTests` → `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `PRODUCT_BUNDLE_IDENTIFIER = com.example.MerchantCatalog`.
- [ ] **Step 5:** Commit `chore: add Xcode project skeleton`.

### Task 2: ServiceContainer

**Files:**
- Create: `MerchantCatalog/Core/DI/ServiceContainerType.swift`, `MerchantCatalog/Core/DI/ServiceContainer.swift`
- Test: `MerchantCatalogTests/Core/DI/ServiceContainerTests.swift`

**Interfaces — Produces:**
```swift
@MainActor protocol ServiceContainerType: AnyObject {
    func register<T>(_ service: T)
    func resolve<T>() -> T?
    func forceResolve<T>() -> T          // fatalError naming T when missing
}
@MainActor final class ServiceContainer: ServiceContainerType { init() }
```

- [ ] **Step 1: Write the failing tests** (`@MainActor struct ServiceContainerTests`, fixture `protocol GreeterType { func greet() -> String }`, `final class Greeter: GreeterType`):
  - `registerThenResolveReturnsTheSameInstance`: register `greeter as any GreeterType`; `resolve() as (any GreeterType)?` is `===` the instance; `forceResolve()` greets `"hi"`.
  - `resolveMissingReturnsNil`: empty container → `(any GreeterType)?` is `nil`.
  - `registeringTheSameTypeTwiceOverwrites`: register `Counter(value: 1)` then `Counter(value: 2)` → resolves `2`.
  - `resolvesOnlyUnderTheRegisteredType`: register as `any GreeterType` → `resolve() as Greeter?` is `nil`.
  - `sameNamedTypesInDifferentScopesDoNotCollide`: `ScopeA.Config(value: 1)`, `ScopeB.Config(value: 2)` both resolve to their own value.
- [ ] **Step 2:** Run `xcodebuild … test` → compile error `cannot find 'ServiceContainer' in scope`.
- [ ] **Step 3:** Implement with `private var services: [ObjectIdentifier: Any]`.
- [ ] **Step 4:** Run tests → 5 passed.
- [ ] **Step 5:** Commit `feat: add ServiceContainer`.

### Task 3: AppContext

**Files:**
- Create: `MerchantCatalog/App/AppContext.swift`
- Modify: `MerchantCatalog/App/MerchantCatalogApp.swift` (hold `private let context = AppContext.configure()`; log launch in Task 4)
- Test: `MerchantCatalogTests/App/AppContextRegistrationTests.swift`

**Interfaces:**
- Consumes: `ServiceContainerType`, `ServiceContainer` (Task 2).
- Produces: `@MainActor final class AppContext { let container: any ServiceContainerType; static func configure() -> AppContext }`. `configure()` registers every service under its protocol type (none in S0; S1 starts adding).

- [ ] **Step 1: Write the failing test** `configureBuildsAnIndependentContainer`: register a fixture value in `AppContext.configure().container`; a second `configure()`'s container resolves `nil` for that type.
- [ ] **Step 2:** Run tests → compile error `cannot find 'AppContext' in scope`.
- [ ] **Step 3:** Implement `AppContext`; doc comment on the Configurator `resolveDependencies(from:)` rule (decision above).
- [ ] **Step 4:** Run tests → all passed.
- [ ] **Step 5:** Commit `feat: add AppContext composition root`.

### Task 4: Log categories, Route and Router

**Files:**
- Create: `MerchantCatalog/Core/Logging/Log.swift`, `MerchantCatalog/Core/Navigation/Route.swift`, `MerchantCatalog/Core/Navigation/Router.swift`
- Modify: `MerchantCatalog/App/MerchantCatalogApp.swift` (`Log.lifecycle.info` on launch)
- Test: `MerchantCatalogTests/Core/Navigation/RouterTests.swift`

**Interfaces — Produces:**
```swift
enum Log {  // subsystem = Bundle.main.bundleIdentifier ?? "com.example.MerchantCatalog"
    static let lifecycle, navigation, network, analytics, experiment, persistence, performance: Logger
}
enum Route: Hashable { case productDetail(productID: Int) }
@MainActor @Observable final class Router {
    var path: [Route]                   // bound to NavigationStack(path:)
    init(path: [Route] = [])
    func push(_ route: Route)
    func pop()                          // no-op on empty path
    func popToRoot()
}
```
Router logs push/pop/popToRoot to `Log.navigation` at `.debug` (route `.public`; ids only).

- [ ] **Step 1: Write the failing tests** (`@MainActor struct RouterTests`):
  - `startsEmpty`: `Router().path == []`.
  - `pushAppendsRoute`: push 1, push 2 → `[.productDetail(productID: 1), .productDetail(productID: 2)]`.
  - `popRemovesLastRoute`: path `[1, 2]` → pop → `[1]`.
  - `popOnEmptyPathIsNoOp`: pop on `[]` → `[]`.
  - `popToRootClearsPath`: path `[1, 2, 3]` → `[]`.
  - `popToRootOnEmptyPathIsNoOp`.
- [ ] **Step 2:** Run tests → compile error `cannot find 'Router' in scope`.
- [ ] **Step 3:** Implement `Log`, `Route`, `Router`.
- [ ] **Step 4:** Run tests → all passed.
- [ ] **Step 5:** Commit `feat: add Router, Route and Log categories`.

### Task 5: AppTabView and the navigation rule

**Files:**
- Create: `MerchantCatalog/App/AppTab.swift` (`enum AppTab: Hashable { case catalog, saved }`)
- Create: `MerchantCatalog/App/AppTabView.swift`
- Modify: `MerchantCatalog/App/MerchantCatalogApp.swift` (`WindowGroup { AppTabView() }`)
- Test: `MerchantCatalogTests/App/NavigationRuleTests.swift`

**Interfaces:**
- Consumes: `Router`, `Route` (Task 4).
- Produces: `AppTabView` — iOS 26 `TabView(selection:)` with `Tab("Catalog", systemImage: "square.grid.2x2", value: .catalog)` and `Tab("Saved", systemImage: "bookmark", value: .saved)`; `@State` `selection`, `catalogRouter`, `savedRouter`; each tab is `NavigationStack(path: $router.path)` with a `ContentUnavailableView` placeholder root and `.navigationDestination(for: Route.self)`. Placeholder copy: Catalog — "Products will appear here."; Saved — "Saved products will appear here." Detail placeholder: `Text("Product \(id)")`.

- [ ] **Step 1: Write the failing test** `onlyAppTabViewOwnsNavigation`: locate the repo root by walking up from `#filePath` to the folder containing `MerchantCatalog.xcodeproj`; scan every `.swift` file under `MerchantCatalog/`; offenders = any `NavigationLink`/`NavigationView`, and `NavigationStack`/`navigationDestination` outside `MerchantCatalog/App/AppTabView.swift`. `#expect(offenders == [])`, `#expect(!scannedFiles.isEmpty)`, and `#expect(appTabViewSource.contains("NavigationStack"))` (positive control).
- [ ] **Step 2:** Run tests → fails: AppTabView.swift not found (positive control).
- [ ] **Step 3:** Implement `AppTab`, `AppTabView`; wire into `MerchantCatalogApp`.
- [ ] **Step 4:** Run full suite → all passed; build → 0 warnings.
- [ ] **Step 5:** Commit `feat: add AppTabView with Catalog and Saved tabs`.

### Task 6: Docs and review gate

**Files:** Modify `docs/Architecture.md` (§ 2 note on folders, § 6 `configure()`/Configurator rule, § 7 S0 `Route`), `README.md` (run/test line), `CLAUDE.md` (commands verified), `docs/ImplementationPlan.md` (status, decisions, review log), `docs/AILog.md` (developer choice on registration guard, if AI output was changed).

- [ ] **Step 1:** Clean build (`xcodebuild clean build`) → 0 warnings; full `xcodebuild test` → counts recorded.
- [ ] **Step 2:** Update docs to match reality.
- [ ] **Step 3:** Review log entry: branch, head commit, files, test counts, warnings 0, manual Simulator checks (launch; both tabs show placeholders; switching tabs works), limitations, open questions.
- [ ] **Step 4:** Set S0 `READY_FOR_REVIEW`; commit `docs: record S0 review gate`.
