# S6 — Card Rating Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `product_card_density_v1` runs locally end to end: each installation is bucketed once (SHA-256), the catalog and search cards show the rating only in `treatment` with equal height in both arms, `experiment_exposed` fires once per session at the first rendered card, `experiment_assignments` describes the installation, and DEBUG Diagnostics can force a variant.

**Architecture:** `ExperimentAssigner` (pure) buckets an installation id. `LocalExperimentService` (behind `ExperimentService`, `@MainActor`) resolves each experiment **once per launch**: DEBUG override > stored assignment > hashed (then stored), and sets `experiment_assignments`. `ExposureTracker` (`@MainActor`) sends `experiment_exposed` once per experiment per session id. `CatalogConfigurator` builds a `CardExperiment` value (launch assignment + tracker) for `CatalogViewModel`: its feeds build `ProductCardModel(product:variant:)`, and `itemAppeared(id:in:)` reports the first visible card after its hidden-list guard. Diagnostics talks to the DEBUG-only `ExperimentOverrides` protocol; changes apply at the next launch.

**Tech Stack:** Xcode 26.0, Swift 6 language mode (strict concurrency complete, no default isolation), SwiftUI iOS 26.0, Observation, CryptoKit (system framework), Swift Testing. No packages.

**Spec:** [ImplementationPlan.md § S6](../ImplementationPlan.md#s6--card-rating-experiment-product_card_density_v1), [Experiments.md](../Experiments.md), [Analytics.md § 2, § 3 Experiments](../Analytics.md), [ProductSpecification.md § 4.1, § 4.5](../ProductSpecification.md#41-catalog-browse), [Architecture.md § 2, § 4–6](../Architecture.md). Builds on [S5](S5-saved-products.md).

## Global Constraints

- Neutral naming only (`MerchantCatalog`). No third-party dependencies. No caching (D-10).
- Bucketing (Experiments.md): first 8 bytes of `SHA-256("product_card_density_v1:" + installation_id)` as `UInt64` (big-endian), modulo 10 000; `< 5 000` → `control`, else `treatment`. `installation_id` is `UUID.uuidString` (uppercase, as in the envelope). Never `hashValue`.
- Developer decisions (2026-11-13): D-69 assignment resolved once per launch, override and reset apply at the next launch; D-70 `CardExperiment` value injected into `CatalogViewModel`, exposure from `itemAppeared`; D-71 card rating "★ 4.9" (one fraction digit), hidden placeholder row in control; D-72 the installation reset keeps the override.
- Analytics code and Analytics.md change in the same commit; `TaxonomyDocumentationTests` stays green.
- Swift Testing; view-model suites `@Suite(.timeLimit(.minutes(1)))`; isolated `UserDefaults` (`IsolatedDefaults`); no live network.
- Overrides are DEBUG only (`#if DEBUG`); Release must build with 0 warnings.

## Review Focus

1. A stored assignment must win over a changed hash (allocation change, or a different id after a reset without clearing). `storedAssignmentIsReused` (Task 2).
2. An override changed mid-launch must not change the cards, the exposure or the user property until the next launch. `assignmentIsResolvedOncePerLaunch` (Task 2).
3. The hidden browse layer's cards fire `onAppear` while search shows: no exposure from them. `hiddenListCardDoesNotExpose` (Task 4).
4. The first event of a cold launch can be the exposure itself (no session yet): it must still dedupe within the session it started. `exposureStartingTheSessionIsDeduplicated` (Task 3).
5. A stored value that isn't a known variant (corrupt defaults, future variant) → re-bucketed, not a crash. `unknownStoredVariantIsReassigned` (Task 2).

---

### Task 1: Experiment types and bucketing

**Files:** Create `MerchantCatalog/Core/Experiments/{Experiment, ExperimentAssigner}.swift`; Test `MerchantCatalogTests/Core/Experiments/ExperimentAssignerTests.swift`.

**Interfaces — Produces:**
- `enum Experiment: String, CaseIterable, Sendable { case productCardDensity = "product_card_density_v1" }`
- `enum ExperimentVariant: String, CaseIterable, Sendable { case control, treatment }`
- `enum AssignmentSource: String, Sendable { case hashed, override }`
- `struct ExperimentAssignment: Equatable, Sendable { let variant: ExperimentVariant; let source: AssignmentSource }`
- `enum ExperimentAssigner` (nonisolated): `static let bucketCount = 10_000`, `static let controlBuckets = 5_000`, `static func bucket(for: Experiment, installationID: UUID) -> Int`, `static func variant(for: Experiment, installationID: UUID) -> ExperimentVariant`.

- [x] **Step 1: Failing tests.** `goldenBuckets` (parameterized; values computed independently with Python `hashlib`, 2026-11-13): `uuid(0)` → 9656 treatment, `uuid(1)` → 2573 control, `uuid(3)` → 5845 treatment, `E621E1F8-C36C-495A-93FC-0C247A3E6E5F` → 3092 control. `boundaryBucketsSplitTheArms` (4 999 → control, 5 000 → treatment through `variant(forBucket:)`). `distributionIsBalanced`: `uuid(0..<10_000)` → control share within 0.48…0.52 (Python: 4 930).
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement with `CryptoKit.SHA256`. **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: bucket installations into experiment variants`.

### Task 2: Experiment service and `experiment_assignments`

**Files:** Create `MerchantCatalog/Core/Experiments/{ExperimentService, LocalExperimentService}.swift`; Modify `Core/Analytics/{AnalyticsValue, UserProperty}.swift`, `App/AppContext.swift`, `docs/Analytics.md` (§ 2 note); Test `MerchantCatalogTests/Core/Experiments/LocalExperimentServiceTests.swift`, `Core/Analytics/UserPropertyTests` (or the existing user-property suite), `App/AppContextRegistrationTests.swift`.

**Interfaces — Produces:**
- `@MainActor protocol ExperimentService: AnyObject { func assignment(for: Experiment) -> ExperimentAssignment }` — the launch's assignment (D-69).
- DEBUG: `@MainActor protocol ExperimentOverrides: AnyObject { func override(for: Experiment) -> ExperimentVariant?; func setOverride(_: ExperimentVariant?, for: Experiment); func clearStoredAssignments() }` — persisted, read at the next launch.
- `@MainActor final class LocalExperimentService: ExperimentService` (+ `ExperimentOverrides` in DEBUG): `init(defaults: UserDefaults, installation: InstallationIDProvider, analytics: any AnalyticsTracking)`. Keys `experiments.assignments` and (DEBUG) `diagnostics.experiment_overrides`, both `[String: String]` by experiment id. First `assignment(for:)` per process: override → `.override`; else a stored known variant → `.hashed`; else hash, store → `.hashed`; logs `experiment` category; sets `.experimentAssignments` with every experiment resolved so far (effective variants). Later calls return the cached value.
- `AnalyticsValue.stringMap([String: String])`, description `{key: value, …}` sorted by key. `UserProperty.experimentAssignments([String: String])`, name `experiment_assignments`.
- `AppContext.configure` registers `experiments as any ExperimentService` (and DEBUG `as any ExperimentOverrides`) and resolves every `Experiment.allCases` at launch, after the launch properties.

- [x] **Step 1: Failing tests:** `hashedAssignmentIsStored` (id `uuid(1)` → control/hashed; defaults hold `control`); `storedAssignmentIsReused` (store `treatment` for `uuid(1)` → treatment/hashed); `unknownStoredVariantIsReassigned` (`"blue"` → control, stored `control`); `assignmentIsResolvedOncePerLaunch` (override set after the first call → same result; a new service on the same defaults → override); `overrideWinsAndKeepsTheStoredAssignment` (override treatment for `uuid(1)` → treatment/override; stored stays absent or `control`; override `nil` + new service → control/hashed); `resetRebucketsWithTheNewID` (installation `uuid(1)` → control; `installation.reset()` with `makeID` → `uuid(0)`, `clearStoredAssignments()`, new service → treatment); `overrideSurvivesClearingAssignments`; `assignmentSetsTheUserProperty` (`SpyAnalytics.userProperties == [.experimentAssignments(["product_card_density_v1": "control"])]`). Value/property: `stringMapDescriptionIsSorted`, `experimentAssignmentsProperty` (name, `.stringMap`). Registration: `experimentServiceIsRegisteredByProtocol` (+ DEBUG overrides), `launchSetsExperimentAssignments` (the DEBUG `InMemoryAnalyticsProvider` has `experiment_assignments`).
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: assign experiment variants per installation`.

### Task 3: Exposure tracking and `experiment_exposed`

**Files:** Create `MerchantCatalog/Core/Experiments/ExposureTracker.swift`; Modify `Core/Analytics/AnalyticsEvent.swift`, `docs/Analytics.md` (`experiment_exposed` → Active); Test `MerchantCatalogTests/Core/Experiments/ExposureTrackerTests.swift`, `Core/Analytics/` event-properties test.

**Interfaces — Produces:**
- `enum ExposureSurface: String, Sendable { case catalogGrid = "catalog_grid", searchGrid = "search_grid" }` (in `ExposureTracker.swift`).
- `AnalyticsEvent.experimentExposed(experiment: Experiment, assignment: ExperimentAssignment, surface: ExposureSurface)` → `experiment_id`, `variant`, `assignment_source`, `surface`.
- `@MainActor final class ExposureTracker { init(analytics: any AnalyticsTracking, sessions: SessionTracker); func cardRendered(_: Experiment, assignment: ExperimentAssignment, surface: ExposureSurface) }`: sends when the current session id (read **after** tracking, so an exposure that starts the cold session counts) differs from the last exposed one for that experiment; otherwise `Log.experiment.debug`. Registered in `AppContext`.

- [x] **Step 1: Failing tests:** `experimentExposedProperties`; `firstRenderSendsExposure`; `laterRendersInTheSessionAreSuppressed` (also from `searchGrid`); `newSessionExposesAgain` (`AppLifecycleTracker` + `TestNow`: background 30 min → active → render sends again); `exposureStartingTheSessionIsDeduplicated` (real `AnalyticsService` + `SpyAnalyticsProvider`, no session: two renders → `session_started`, one `experiment_exposed`); `bothArmsAreExposed` (control assignment sends too). Registration: `exposureTrackerIsRegistered`.
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run → pass, `TaxonomyDocumentationTests` included.
- [x] **Step 5:** Commit `feat: track experiment exposure once per session`.

### Task 4: Rating on treatment cards and exposure from the grid

**Files:** Create `Features/Catalog/Presentation/CardExperiment.swift`; Modify `Features/Catalog/Presentation/{ProductCardModel, ProductCardView, CatalogFeed, CatalogViewModel, CatalogConfigurator, CatalogView}.swift`; Test `MerchantCatalogTests/Features/Catalog/{ProductCardModelTests, CatalogViewModelExperimentTests}.swift`, VM suites' call sites (helper `controlCardExperiment()` in test support).

**Interfaces — Produces:**
- `@MainActor struct CardExperiment { init(assignment: ExperimentAssignment, exposure: ExposureTracker); var variant: ExperimentVariant; func cardRendered(in: ListContext) }` (`browse` → `catalogGrid`, `search` → `searchGrid`).
- `ProductCardModel.init(product:variant:locale:)`; `let rating: Double?` and `let ratingText: String?` (`"4.9"`: `.number.precision(.fractionLength(1))`), set only in `treatment` and only when the product has a rating. Placeholder cards have none.
- `CatalogFeed.init(query:sort:cardVariant:)`. `CatalogViewModel.init(…, cardExperiment: CardExperiment, clock:)`; `itemAppeared(id:in:)` calls `cardExperiment.cardRendered(in:)` for a loaded card of the list on screen, before the pagination guard.
- View: rating row (`star.fill` + text, `.subheadline`, secondary) always laid out; in control it is a hidden placeholder (same height, D-21), not read by VoiceOver. The grid passes `card.rating` to `ProductCardAccessibility.label`.

- [x] **Step 1: Failing tests:** `ProductCardModelTests`: `treatmentCardShowsTheRating` (4.94 → `rating 4.94`, `"4.9"` in `en_US`), `controlCardHasNoRating`, `treatmentWithoutRatingShowsNone`. VM: `treatmentCardsCarryTheRating` (browse and search feeds), `controlCardsHaveNoRating`, `firstBrowseCardExposesCatalogGrid`, `firstSearchCardExposesSearchGrid`, `hiddenListCardDoesNotExpose`, `cardOfUnloadedListDoesNotExpose`, `exposureIsOncePerSession` (two appearances → one event). Registration: `catalogDependenciesResolve` still green with the new services.
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement (UI included). **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: show the rating on treatment cards`.

### Task 5: Diagnostics override

**Files:** Modify `Features/Diagnostics/Presentation/{DiagnosticsViewModel, DiagnosticsConfigurator, DiagnosticsView}.swift`; Test `MerchantCatalogTests/Features/Diagnostics/DiagnosticsViewModelTests.swift`, `AppContextRegistrationTests`.

**Interfaces — Produces:**
- `DiagnosticsViewModel.init(…, experiments: any ExperimentService, overrides: any ExperimentOverrides, …)`; `let cardAssignment: ExperimentAssignment` (this launch); `var cardOverride: ExperimentVariant?` (`didSet` → `setOverride`, log); `resetInstallationID()` also calls `clearStoredAssignments()` (override kept, D-72).
- View: section "Experiment" — `product_card_density_v1`, "This launch: Treatment (hashed)", picker "Override" Auto / Control / Treatment, footer "Changes apply at the next launch."

- [x] **Step 1: Failing tests:** `showsTheLaunchAssignment`; `overrideChoiceIsPersisted` (treatment → `overrides.override(for:) == .treatment`; Auto → `nil`); `overrideStartsFromTheStoredChoice`; `resetClearsStoredAssignmentsAndKeepsTheOverride`. Registration: `diagnosticsDependenciesResolve`.
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement (UI included). **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add the experiment override to diagnostics`.

### Task 6: Docs and review gate

**Files:** `docs/Experiments.md` (big-endian, uppercase id, per-launch resolution, reset at next launch), `docs/Analytics.md` (§ 2 reset wording), `docs/ProductSpecification.md` (§ 4.1 as built), `docs/Architecture.md` (§ 2, 4, 5, 6 as built), `docs/ImplementationPlan.md` (decisions, review log, status), README status line, AILog if the developer changed AI output, this plan.

- [x] **Step 1:** `xcodebuild … clean build` → result bundle `warningCount` 0; Release build 0 warnings; test-action log without compiler warnings.
- [x] **Step 2:** `xcodebuild … test` → all pass; record counts.
- [x] **Step 3:** Review log with manual Simulator checks (override each variant + relaunch, card rating and equal height, exposure once per session, search surface, reset re-buckets at next launch, VoiceOver label with rating). Status `READY_FOR_REVIEW`.
- [x] **Step 4:** Commit `docs: record S6 review gate`.

## Deviations found during implementation

- Task 2: `launchSetsExperimentAssignments` became an extra expected entry in the existing `launchUserPropertiesReachTheEventLog` (the property is computed from the context's installation id). The cache and the stored-assignment reuse were mutation-checked (without them `assignmentIsResolvedOncePerLaunch` and `storedAssignmentIsReused` fail).
- Task 3: `TaxonomyDocumentationTests.plannedEventsAreAbsentFromCode` no longer expects at least one Planned event: `experiment_exposed` was the last one. `everyEventHeadingHasAStatus` stays the parser's positive control. Reading the session id after tracking was mutation-checked (recording it before tracking sends two exposures in `exposureStartingTheSessionIsDeduplicated`).
- Task 4: catalog suites that don't look at the experiment pass `unobservedCardExperiment()` (`MerchantCatalogTests/Support/CardExperiments.swift`: control, exposures to a spy of their own), so their event assertions are unchanged. Extra tests: `ratingHasOneFractionDigit` (2.51 → "2.5", 4.96 → "5.0", 3.0 → "3.0"); `firstBrowseCardExposesCatalogGrid` runs for both arms. The exposure guard (list on screen, page 1 loaded) was mutation-checked: without it `hiddenListCardDoesNotExpose` and `cardOfUnloadedListDoesNotExpose` fail.
- Task 5: the Diagnostics suite gives `LocalExperimentService` a spy of its own, so `experiment_assignments` doesn't enter the event-log assertions. Clearing the stored assignments on reset was mutation-checked.
- Task 6: no AILog entry: the developer accepted every recommendation (D-69–D-72).
