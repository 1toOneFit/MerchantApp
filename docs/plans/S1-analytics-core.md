# S1 — Analytics Core and Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A swappable, tested analytics base (protocols, enriching service, providers, installation id, sessions, launch user properties, lifecycle events) plus a DEBUG Diagnostics sheet that shows events, user properties and recent logs.

**Architecture:** Features call only `AnalyticsTracking`. `AnalyticsService` stamps each event with an envelope (timestamp, installation id, session id, sequence) taken from `InstallationIDProvider` and `SessionTracker`, then fans out to every `AnalyticsProvider`. `AppLifecycleTracker` turns scene phases into lifecycle events and session boundaries. The whole stack is `@MainActor` and synchronous (D-33). Diagnostics is a DEBUG-only scene with its own Configurator, the first real case of the S0 registration guard.

**Tech Stack:** Xcode 26.0, Swift 6.2 compiler in Swift 6 language mode, SwiftUI (iOS 26.0), Observation, `os.Logger`, `OSLogStore`, `UserDefaults`, Swift Testing. No packages.

**Spec:** [ImplementationPlan.md § S1](../ImplementationPlan.md#s1--analytics-core-and-diagnostics), [Analytics.md](../Analytics.md), [Architecture.md § 4, § 5, § 6, § 10](../Architecture.md), [ProductSpecification.md § 3](../ProductSpecification.md#3-navigation) (Diagnostics entry point).

## Global Constraints

- Neutral naming only (`MerchantCatalog`). No third-party dependencies. No caching.
- `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation (D-31). Verified on the branch with `-showBuildSettings` (2026-11-13).
- Features and view models depend only on `AnalyticsTracking`; only `AppContext` names concrete analytics types; services are registered under their protocol where one exists.
- Analytics code and `docs/Analytics.md` change in the same commit; `TaxonomyDocumentationTests` keeps them equal.
- Durations are whole seconds (`_s`), rounded down, never negative. Session timeout: 30 minutes; a gap of exactly 30:00 starts a new session.
- No free text, query text or personal data in analytics. Analytics logs at `debug` level in the `analytics` category.
- `NavigationStack` stays only in `App/AppTabView.swift` (the Diagnostics sheet's stack lives there).
- DEBUG-only code (`InMemoryAnalyticsProvider`, log reader, Diagnostics) is wrapped in `#if DEBUG`; the Release configuration must still compile.
- Verify with `xcodebuild build` (0 warnings in the result bundle) and `xcodebuild test` on `platform=iOS Simulator,name=iPhone 17,OS=26.0`. Never launch or drive the app in the Simulator.

## Decisions taken in this plan

| Decision | By | Why |
|---|---|---|
| D-33: `AnalyticsTracking`, `AnalyticsProvider`, `AnalyticsService`, `SessionTracker`, `InstallationIDProvider`, `AppLifecycleTracker` are `@MainActor`; `track(_:)` is synchronous | Developer (scope confirmation) | Every caller is already main-actor UI code; event order and sequence numbers stay deterministic; no unstructured `Task`s. A future vendor provider hops off the main actor inside itself. |
| D-34: DEBUG "Reset installation ID" simulates a fresh install: new id, new `first_seen_date`, the next session has `is_first_session = true`, and a `session_started` (`launch_kind = cold`) is sent immediately | Developer (scope confirmation) | Consistent with a reinstall, which is what the reset stands for. |
| D-35: Sessions and durations use the injected wall clock (`() -> Date`); negative intervals (clock moved back) count as 0 | Agent | Envelope timestamps need wall time anyway; one time source keeps tests simple. Analytics SDKs commonly time sessions this way. |
| D-36: A cold session starts at the first `.active` scene phase **or** the first tracked event, whichever comes first; exactly one `session_started` either way | Agent | From S2 on, a view can track before the scene reports `.active`; every event must carry a session id. |
| `first_seen_date` and the envelope `timestamp` are UTC; `timestamp` has millisecond precision | Agent | Matches "ISO 8601, UTC"; ms keeps same-second events readable (the `sequence` orders them). |
| `app_version` reports `CFBundleShortVersionString` verbatim (`1.0` today) | Agent | No build-setting change; the Analytics.md example is updated. |
| `AnalyticsValue` has `string`, `int`, `bool` only | Agent | YAGNI: `double` (S5 `price`) and a map (S6 `experiment_assignments`) arrive with their first event or property. |
| User-property de-duplication is in memory only: each launch sets every launch property once | Agent | Matches "updated when: launch"; a vendor's identify call is per launch too. |

## Review Focus

1. **Stored installation id is not a UUID** (corrupt or hand-edited defaults) → a new id is created and persisted → Task 2 `invalidStoredValueIsReplaced`.
2. **Wall clock moves backwards** between background and foreground → durations are 0 and no new session → Task 5 `clockMovingBackwardsGivesZeroDurations`.
3. **An event is tracked before the scene first becomes active** → exactly one `session_started`, sent first with sequence 1 → Task 4 `firstEventStartsAColdSessionFirst`, Task 5 `firstActiveAfterAnEarlyEventDoesNotStartASecondSession`.
4. **Prewarmed or background launch** (`.background` before any `.active`) → no `app_backgrounded`; the later `.active` starts the cold session → Task 5 `backgroundBeforeFirstActiveIsIgnored`.
5. **Repeated or transient phases** (`onChange(initial: true)` repeats `.active`; Control Center gives `.active → .inactive → .active`) → no duplicate events → Task 5 `repeatedAndInactivePhasesSendNothing`.

---

### Task 1: Event model and taxonomy contract

**Files:**
- Create: `MerchantCatalog/Core/Analytics/AnalyticsValue.swift`, `MerchantCatalog/Core/Analytics/AnalyticsEvent.swift`
- Create: `MerchantCatalogTests/Support/RepositoryFiles.swift` (moved out of `NavigationRuleTests`: `repositoryRoot(from:)`, `swiftSources(in:root:)`, plus `text(at:root:)`)
- Modify: `MerchantCatalogTests/App/NavigationRuleTests.swift` (use `RepositoryFiles`)
- Modify: `docs/Analytics.md` (`session_started`, `app_foregrounded`, `app_backgrounded` → **Active**)
- Test: `MerchantCatalogTests/Core/Analytics/AnalyticsEventTests.swift`, `MerchantCatalogTests/Core/Analytics/TaxonomyDocumentationTests.swift`

**Interfaces — Produces:**
- `enum AnalyticsValue: Equatable, Sendable { case string(String), int(Int), bool(Bool) }` with `var description: String` (plain value text).
- `enum AnalyticsEventName: String, CaseIterable, Sendable` — `sessionStarted = "session_started"`, `appForegrounded = "app_foregrounded"`, `appBackgrounded = "app_backgrounded"`.
- `enum LaunchKind: String, Sendable { case cold, resume }`.
- `enum AnalyticsEvent: Equatable, Sendable` — `.sessionStarted(isFirstSession: Bool, launchKind: LaunchKind)`, `.appForegrounded(backgroundDurationS: Int)`, `.appBackgrounded(foregroundDurationS: Int)`; `var name: AnalyticsEventName`, `var properties: [String: AnalyticsValue]`.

- [ ] **Step 1: Write failing tests.** `AnalyticsEventTests.namesAndProperties` (parameterized): `.sessionStarted(isFirstSession: true, launchKind: .cold)` → `session_started`, `["is_first_session": .bool(true), "launch_kind": .string("cold")]`; `.appForegrounded(backgroundDurationS: 42)` → `["background_duration_s": .int(42)]`; `.appBackgrounded(foregroundDurationS: 7)` → `["foreground_duration_s": .int(7)]`. `TaxonomyDocumentationTests`: `activeEventsInDocsMatchCode` (Active headings == `AnalyticsEventName.allCases` raw values), `plannedEventsAreAbsentFromCode`, `everyEventHeadingHasAStatus` (positive control: > 0 headings; each has `Active` or `Planned (S<n>)`).
- [ ] **Step 2:** Run tests → compile failure (types missing).
- [ ] **Step 3:** Implement the types; move the repository helpers; flip the three statuses in Analytics.md.
- [ ] **Step 4:** Run tests → pass (including `NavigationRuleTests`).
- [ ] **Step 5:** Commit `feat: add analytics event model and taxonomy test`.

### Task 2: Installation id

**Files:**
- Create: `MerchantCatalog/Core/Analytics/InstallationIDProvider.swift`
- Create: `MerchantCatalogTests/Support/IsolatedDefaults.swift` (unique suite per instance, removed in `deinit`), `MerchantCatalogTests/Support/TestNow.swift` (`@MainActor final class TestNow { var date: Date; func advance(by: TimeInterval); var now: () -> Date }`), `MerchantCatalogTests/Support/TestUUIDs.swift` (`func uuid(_ n: Int) -> UUID`, `final class SequentialUUIDs { var next: () -> UUID }`)
- Test: `MerchantCatalogTests/Core/Analytics/InstallationIDProviderTests.swift`

**Interfaces — Produces:** `@MainActor final class InstallationIDProvider` — `init(defaults: UserDefaults, now: @escaping () -> Date = Date.init, makeID: @escaping () -> UUID = UUID.init)`; `private(set) var installationID: UUID`; `private(set) var firstSeenDate: Date`; `func reset()`. Keys `analytics.installation_id` (String), `analytics.first_seen_date` (Date). Loads or creates in `init`.

- [ ] **Step 1: Write failing tests:** `createdOnceAndPersisted` (two providers on the same defaults → same id; `makeID` called once); `firstSeenDateIsCreationTime`; `resetProducesNewIDAndFirstSeenDate` (and a new provider reads them back); `invalidStoredValueIsReplaced` (`"not-a-uuid"` stored → new id persisted).
- [ ] **Step 2:** Run → compile failure.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: add InstallationIDProvider`.

### Task 3: Session tracker

**Files:** Create `MerchantCatalog/Core/Analytics/SessionTracker.swift`; Test `MerchantCatalogTests/Core/Analytics/SessionTrackerTests.swift`.

**Interfaces — Produces:**
- `struct AnalyticsSession: Equatable, Sendable { let id: UUID; let startedAt: Date }`.
- `@MainActor final class SessionTracker` — `static let defaultTimeout: TimeInterval = 30 * 60`; `init(defaults: UserDefaults, timeout: TimeInterval = SessionTracker.defaultTimeout, makeID: @escaping () -> UUID = UUID.init)`; `private(set) var current: AnalyticsSession?`; `func startSession(kind: LaunchKind, at date: Date) -> AnalyticsEvent` (new session, sequence reset, returns `.sessionStarted`); `func isExpired(afterBackground duration: TimeInterval) -> Bool` (`>= timeout`); `func nextSequence() -> Int` (1-based within the current session); `func resetForNewInstallation()` (ends the session, next start is first). Persisted key `analytics.has_started_session` (Bool).

- [ ] **Step 1: Write failing tests:** `noSessionBeforeStart`; `firstStartIsFirstSession` (event `is_first_session: true`, `launch_kind` echoed); `laterStartsAreNotFirstAcrossInstances` (new tracker, same defaults → `false`); `sequenceIncrementsAndResetsPerSession` (1,2,3 → new session → 1); `expiryRule` (parameterized: 0 → false, 1799 → false, 1800 → true, 7200 → true); `resetForNewInstallationEndsSessionAndNextIsFirst`.
- [ ] **Step 2:** Run → compile failure.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: add SessionTracker`.

### Task 4: Tracking protocols, envelope and AnalyticsService

**Files:**
- Create: `MerchantCatalog/Core/Analytics/AnalyticsTracking.swift`, `AnalyticsProvider.swift`, `AnalyticsEnvelope.swift`, `UserProperty.swift`, `AnalyticsService.swift` (all under `Core/Analytics/`)
- Create: `MerchantCatalogTests/Fakes/SpyAnalytics.swift`, `MerchantCatalogTests/Fakes/SpyAnalyticsProvider.swift`
- Test: `MerchantCatalogTests/Core/Analytics/AnalyticsServiceTests.swift`

**Interfaces — Produces:**
- `@MainActor protocol AnalyticsTracking { func track(_ event: AnalyticsEvent); func setUserProperty(_ property: UserProperty) }`.
- `@MainActor protocol AnalyticsProvider { func send(_ envelope: AnalyticsEnvelope); func userPropertyDidChange(_ change: UserPropertyChange) }`.
- `struct AnalyticsEnvelope: Equatable, Sendable { let event: AnalyticsEvent; let timestamp: Date; let installationID: UUID; let sessionID: UUID; let sequence: Int; var fields: [String: AnalyticsValue] }` — `fields` = `event`, `timestamp` (ISO 8601 UTC with ms, e.g. `2026-11-13T10:00:00.000Z`), `installation_id`, `session_id` (`uuidString`), `sequence`.
- `enum UserProperty: Equatable, Sendable` — `appVersion(String)`, `buildNumber(String)`, `osVersion(String)`, `deviceModel(String)`, `firstSeenDate(Date)`, `isDebugBuild(Bool)`; `var name: String` (snake_case per Analytics.md § 2); `var value: AnalyticsValue` (`first_seen_date` → `yyyy-MM-dd` UTC).
- `struct UserPropertyChange: Equatable, Sendable { let name: String; let oldValue: AnalyticsValue?; let newValue: AnalyticsValue }`.
- `@MainActor final class AnalyticsService: AnalyticsTracking` — `init(providers: [any AnalyticsProvider], installation: InstallationIDProvider, sessions: SessionTracker, now: @escaping () -> Date = Date.init)`. `track` starts a cold session first when `sessions.current == nil` (D-36). `setUserProperty` forwards only when `value` differs from the last value for that `name`.
- Spies: `SpyAnalytics` (`events: [AnalyticsEvent]`, `userProperties: [UserProperty]`), `SpyAnalyticsProvider` (`envelopes`, `changes`).

- [ ] **Step 1: Write failing tests:** `envelopeFieldsArePresentAndTyped` (exact `fields` for a fixed date/ids); `firstEventStartsAColdSessionFirst` (`session_started` cold seq 1, then the event seq 2, same session id); `sequenceRestartsInANewSession`; `everyProviderReceivesEveryEvent` (three spies, identical envelopes, in order); `everyProviderReceivesUserPropertyChanges`; `userPropertyEmitsOnlyOnChange` (same value twice → one change `nil → v`; new value → `v → w`); `firstSeenDateValueIsUTCDay` (`2026-11-14T03:30:00Z` → `"2026-11-14"`).
- [ ] **Step 2:** Run → compile failure.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: add AnalyticsService with envelope and provider fan-out`.

### Task 5: Lifecycle events from scene phases

**Files:** Create `MerchantCatalog/Core/Analytics/AppLifecycleTracker.swift`; Test `MerchantCatalogTests/Core/Analytics/AppLifecycleTrackerTests.swift`.

**Interfaces — Produces:** `enum AppPhase: Sendable { case active, inactive, background }`; `@MainActor final class AppLifecycleTracker` — `init(analytics: any AnalyticsTracking, sessions: SessionTracker, now: @escaping () -> Date = Date.init)`; `func handle(_ phase: AppPhase)`. Logs phase changes and session starts to `Log.lifecycle` (info).

State machine: first `.active` → cold session if none (track its `session_started`), no `app_foregrounded`. `.background` while active → `app_backgrounded(foreground_duration_s)`. `.active` after `.background` → if the gap is expired, `session_started(resume)` first; then `app_foregrounded(background_duration_s)`. `.inactive` and repeats → nothing.

- [ ] **Step 1: Write failing tests** (SpyAnalytics + real `SessionTracker` + `TestNow`): `coldLaunchStartsASessionWithoutForegrounded`; `backgroundSendsForegroundDuration` (active, +95 s, background → `foreground_duration_s: 95`); `resumeUnderTimeoutKeepsSession` (+29 min → only `app_foregrounded(1740)`, same session id); `resumeAtTimeoutStartsNewSessionFirst` (+30 min → `session_started(resume, first: false)` then `app_foregrounded(1800)`); `repeatedAndInactivePhasesSendNothing`; `backgroundBeforeFirstActiveIsIgnored`; `firstActiveAfterAnEarlyEventDoesNotStartASecondSession`; `clockMovingBackwardsGivesZeroDurations`.
- [ ] **Step 2:** Run → compile failure.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: send lifecycle events from scene phases`.

### Task 6: Launch user properties

**Files:** Create `MerchantCatalog/Core/Analytics/AppInfo.swift`; Modify `UserProperty.swift`; Test `MerchantCatalogTests/Core/Analytics/LaunchUserPropertiesTests.swift`.

**Interfaces — Produces:** `struct AppInfo: Equatable, Sendable { let appVersion, buildNumber, osVersion, deviceModel: String; let isDebugBuild: Bool }`; `static func current() -> AppInfo` (Bundle `CFBundleShortVersionString`/`CFBundleVersion`, `"unknown"` when missing; `ProcessInfo`; `uname`; `#if DEBUG`); `static func osVersionString(_ version: OperatingSystemVersion) -> String`; `static func deviceModel(machine: String, environment: [String: String]) -> String` (`SIMULATOR_MODEL_IDENTIFIER` wins). `extension UserProperty { static func launchProperties(app: AppInfo, firstSeenDate: Date) -> [UserProperty] }` (order: app_version, build_number, os_version, device_model, first_seen_date, is_debug_build).

- [ ] **Step 1: Write failing tests:** `osVersionString` (parameterized: 26.0.0 → `26.0`, 26.1.2 → `26.1.2`); `deviceModel` (parameterized: env `iPhone18,3` + machine `arm64` → `iPhone18,3`; no env + `iPhone17,1` → `iPhone17,1`); `launchPropertiesListsAllSix`.
- [ ] **Step 2:** Run → compile failure.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: add launch user properties`.

### Task 7: Logging and in-memory providers

**Files:** Create `MerchantCatalog/Core/Analytics/Providers/LoggingAnalyticsProvider.swift`, `MerchantCatalog/Core/Analytics/Providers/InMemoryAnalyticsProvider.swift` (`#if DEBUG`); Tests `MerchantCatalogTests/Core/Analytics/LoggingAnalyticsProviderTests.swift`, `InMemoryAnalyticsProviderTests.swift`.

**Interfaces — Produces:**
- `@MainActor final class LoggingAnalyticsProvider: AnalyticsProvider` — `init(logger: Logger = Log.analytics)`; `static func message(for envelope: AnalyticsEnvelope) -> String` → `event session_started #1 session <uuid> {is_first_session=true, launch_kind=cold}` (keys sorted); `static func message(for change: UserPropertyChange) -> String` → `user property app_version: nil → 1.0`. Logged at `debug`, `privacy: .public` (analytics carries no free text, D-18).
- `@MainActor @Observable final class InMemoryAnalyticsProvider: AnalyticsProvider` — `static let defaultCapacity = 500`; `init(capacity: Int = defaultCapacity)`; `private(set) var events: [AnalyticsEnvelope]` (oldest first, at most `capacity`); `private(set) var userProperties: [String: AnalyticsValue]`.

- [ ] **Step 1: Write failing tests:** `eventMessage`, `userPropertyMessage` (exact strings); `dropsOldestBeyondCapacity` (capacity 3, send 5 → sequences 3,4,5); `keepsCurrentUserPropertyValues`.
- [ ] **Step 2:** Run → compile failure.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: add logging and in-memory analytics providers`.

### Task 8: Composition and scene-phase wiring

**Files:** Modify `MerchantCatalog/App/AppContext.swift`, `MerchantCatalog/App/MerchantCatalogApp.swift`, `MerchantCatalog/Core/Logging/Log.swift` (`subsystem` internal); Create `MerchantCatalog/App/AppPhase+ScenePhase.swift`; Tests `MerchantCatalogTests/App/AppContextRegistrationTests.swift`, `MerchantCatalogTests/App/AppPhaseTests.swift`.

**Interfaces — Produces:** `AppContext.configure(defaults: UserDefaults = .standard, appInfo: AppInfo = .current()) -> AppContext`; `let lifecycle: AppLifecycleTracker`. Registers `any AnalyticsTracking`, `InstallationIDProvider`, `SessionTracker`; in DEBUG also `InMemoryAnalyticsProvider` and `any LogReading` (Task 9). Sets the launch user properties. `AppPhase.init(_ phase: ScenePhase)`. The App observes `@Environment(\.scenePhase)` with `.onChange(of:initial: true)`.

- [ ] **Step 1: Write failing tests:** `analyticsServicesAreRegistered` (resolve `any AnalyticsTracking`, `InstallationIDProvider`, `SessionTracker` from `configure(defaults: isolated)`); `launchUserPropertiesReachTheEventLog` (DEBUG: the in-memory provider holds the six launch properties); `AppPhaseTests.mapsScenePhases` (parameterized). Existing `configureBuildsAnIndependentContainer` switches to isolated defaults.
- [ ] **Step 2:** Run → fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: wire analytics into AppContext and scene phases`.

### Task 9: Diagnostics sheet (DEBUG)

**Files:**
- Create: `MerchantCatalog/Core/Logging/LogStoreReader.swift` (`#if DEBUG`: `struct LogEntry: Identifiable, Equatable, Sendable { id: UUID; date: Date; category: String; level: String; message: String }`, `protocol LogReading: Sendable { func recentEntries() async throws -> [LogEntry] }`, `struct OSLogStoreReader: LogReading` — `@concurrent`, `OSLogStore(scope: .currentProcessIdentifier)`, subsystem predicate, last hour, newest 200, newest first)
- Create: `MerchantCatalog/Features/Diagnostics/Presentation/{DiagnosticsViewModel, DiagnosticsView, DiagnosticsConfigurator}.swift` (`#if DEBUG`)
- Modify: `MerchantCatalog/App/AppTabView.swift` (`init(container:)`; DEBUG toolbar button "Diagnostics" on the Catalog root; `.sheet` with `NavigationStack { DiagnosticsConfigurator.make(from:) }`), `MerchantCatalogApp.swift`
- Create: `MerchantCatalogTests/Fakes/FakeLogReader.swift`
- Test: `MerchantCatalogTests/Features/Diagnostics/DiagnosticsViewModelTests.swift`, `AppContextRegistrationTests.diagnosticsDependenciesResolve`

**Interfaces — Produces:**
- `@MainActor @Observable final class DiagnosticsViewModel` — `init(eventLog: InMemoryAnalyticsProvider, installation: InstallationIDProvider, sessions: SessionTracker, analytics: any AnalyticsTracking, logReader: any LogReading, now: @escaping () -> Date = Date.init)`; `var events: [AnalyticsEnvelope]` (newest first); `var userProperties: [DiagnosticsProperty]` (sorted by name; `DiagnosticsProperty: Identifiable { name; value: String }`); `var installationID: String`; `var sessionID: String?`; `private(set) var logs: LogsState` (`.idle`, `.loaded([LogEntry])`, `.failed(String)`); `func loadLogs() async`; `func resetInstallationID()` (D-34: `installation.reset()`, `sessions.resetForNewInstallation()`, track `sessions.startSession(kind: .cold, at: now())`, `setUserProperty(.firstSeenDate(installation.firstSeenDate))`).
- `@MainActor enum DiagnosticsConfigurator` — `struct Dependencies`; `static func resolveDependencies(from: any ServiceContainerType) -> Dependencies?`; `static func make(from: any ServiceContainerType) -> DiagnosticsView`.

- [ ] **Step 1: Write failing tests:** `eventsAreNewestFirst`; `userPropertiesAreSortedRows`; `loadLogsShowsEntries`; `loadLogsFailureShowsMessage`; `resetStartsAFreshInstallationSession` (new id; new session id; `session_started(first: true, cold)` sequence 1; `first_seen_date` change); `diagnosticsDependenciesResolve`.
- [ ] **Step 2:** Run → compile failure.
- [ ] **Step 3:** Implement the reader, view model, configurator, view (sections: Installation with Reset, User properties, Events with properties, Recent logs with refresh) and the AppTabView entry point.
- [ ] **Step 4:** Run → pass, `NavigationRuleTests` included.
- [ ] **Step 5:** Commit `feat: add DEBUG Diagnostics sheet`.

### Task 10: Docs and review gate

**Files:** `docs/Analytics.md` § 2 (reset, UTC, durations, early-event session rule), `docs/Architecture.md` § 2/§ 4/§ 5/§ 6/§ 10, `docs/ImplementationPlan.md` (decisions D-33–D-36, review log, status), README status line, this plan's checkboxes.

- [ ] **Step 1:** `xcodebuild … clean build` → `** BUILD SUCCEEDED **`; `xcrun xcresulttool get build-results` → `warningCount: 0`.
- [ ] **Step 2:** `xcodebuild … -configuration Release build` → succeeds (DEBUG-only code compiles out).
- [ ] **Step 3:** `xcodebuild … test` → all pass; record counts.
- [ ] **Step 4:** Update docs and the review log (manual Simulator checks, limitations, open questions); status `READY_FOR_REVIEW`.
- [ ] **Step 5:** Commit `docs: record S1 review gate`.
