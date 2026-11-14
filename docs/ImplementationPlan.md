# Implementation Plan and Status

This file is the **persistent source of truth for progress**. A fresh conversation resumes from here (see [CLAUDE.md](../CLAUDE.md) → startup protocol). Keep it accurate before ending any conversation.

## Current state

| Field | Value |
|---|---|
| Phase | **IMPLEMENTATION** |
| Current stage | S8 — Needs attention (`READY_FOR_REVIEW`) |
| Current branch | `feature/needs-attention` (from `develop` at `26dcca2`) |
| Last completed stage | S7 — Release readiness (merged into `develop` with `--no-ff` at `26dcca2`; released to `main` at `aae71db`, 2026-11-14) |
| Next authorized stage | S8 (authorized by the developer, 2026-11-14) |
| Pending human action | Re-review of `feature/needs-attention` after the fixes for the three S8 review findings, the manual Simulator checks in the S8 review log, then approval or further findings |
| Open review findings | — |
| Blockers | — |

## Stage status

Statuses: `PLANNED` → `IN_PROGRESS` → `READY_FOR_REVIEW` → (`CHANGES_REQUESTED` → `READY_FOR_REVIEW`)* → `APPROVED` → `COMPLETED` (merged into `develop` by the developer).

| ID | Stage | Branch | Status | Head commit | Review |
|---|---|---|---|---|---|
| S0 | Project foundation | `feature/project-foundation` | COMPLETED | `ee150e0` | Approved: Codex + developer (2026-11-13); merged into `develop` |
| S1 | Analytics core & diagnostics | `feature/analytics-core` | COMPLETED | `78e51cb` | Approved by the developer (2026-11-13); merged into `develop` with `--no-ff` at `30838a3` |
| S2 | Catalog browsing, networking & images | `feature/catalog-browse` | COMPLETED | `c8a81cb` | Approved: Codex re-review + developer (2026-11-13); merged into `develop` with `--no-ff` at `59415a9` |
| S3 | Search & sort | `feature/search-sort` | COMPLETED | `d70599d` | Approved: Codex re-review + developer (2026-11-13); merged into `develop` with `--no-ff` at `152da21` |
| S4 | Product details | `feature/product-details` | COMPLETED | `34ffb7c` + docs commits | Approved: Codex + developer (2026-11-13); merged into `develop` with `--no-ff` at `46b8e6d` |
| S5 | Saved products | `feature/saved-products` | COMPLETED | `be7c92b` + docs commits | Approved: Codex re-review + developer (2026-11-13); merged into `develop` with `--no-ff` at `dc04338` |
| S6 | Card rating experiment | `feature/card-rating-experiment` | COMPLETED | `7ecdeee` + docs commits | Approved: Codex review fixes + developer (2026-11-13); merged into `develop` with `--no-ff` at `efc5c89` |
| S7 | Release readiness | `feature/release-readiness` | COMPLETED | `87222b6` + docs commits | Approved: developer's own review, Claude and Codex reviews, no findings (2026-11-14); merged into `develop` with `--no-ff` at `26dcca2`; 1.0 released to `main` at `aae71db` |
| S8 | Needs attention | `feature/needs-attention` | READY_FOR_REVIEW | `b16fb72` + docs commits | Review round 1: 3 findings fixed (2026-11-14); awaiting re-review |

The stages run strictly in order, S0 → S8. Each stage branches from `develop` **after** the previous stage was approved and merged into `develop` by the developer.

## Git flow

```text
main      ●──────────────────────────────────────────────●  (release: develop → main, by the developer, after S7)
           \                                            /
develop     ●──────●──────●──────●── … ──●──────●──────●
                 /      /      /               /
feature/…   S0 ●      S1 ●   S2 ●     …      S7 ●
```

- `main`: the initial planning commit, then releases only.
- `develop`: integration branch. Every feature branch starts here and is merged back here.
- `feature/<stage>`: one per stage, local only.
- The agent never merges, pushes or rebases. The developer merges each approved stage into `develop` (`--no-ff` keeps the stage visible in history), merges `develop` → `main` at release, and decides when to push.

## Workflow rules (every stage)

1. **Start:** fresh conversation → startup protocol in CLAUDE.md → confirm the stage is authorized → `git switch develop && git switch -c <branch>` → set status `IN_PROGRESS`. Inspect the Swift version, deployment target and concurrency build settings.
2. **Task plan:** write the stage's task-level plan to `docs/plans/S<n>-<slug>.md` (superpowers:writing-plans) before coding.
3. **TDD:** for each behavior, write the failing test, run it and confirm it fails for the right reason, implement the minimum, rerun, refactor, rerun (superpowers:test-driven-development). Use the Swift skills (`swift-concurrency`, `swift-testing`, `swiftui-patterns`, `swift-architecture`, `ios-networking`) during implementation and self-review.
4. **Analytics:** events implemented in the stage switch from `Planned` to `Active` in [Analytics.md](Analytics.md) in the same commit as the code.
5. **Commits:** small and focused, conventional messages, no unrelated changes.
6. **Verification by the agent:** `xcodebuild build` (zero warnings) and `xcodebuild test`. **The agent never runs the app in the Simulator.** Manual Simulator checks are handed to the developer.
7. **Review gate** (below). Then **stop**.

### Review gate

1. Run the full unit-test suite and a clean build.
2. Update affected docs and this file (status, commit, results, limitations, open questions).
3. Record in the **Review log**: branch, head commit, changed-file summary, test results (counts), build warnings (must be 0), the **manual Simulator checks for the developer**, known limitations, open questions.
4. Set status **`READY_FOR_REVIEW`** (never `COMPLETED`).
5. Say exactly: **"This stage is ready. Please run an independent Codex review manually and share the findings."**
6. **Stop.** Do not invoke Codex, assume approval, merge, push, or start the next stage.

Review findings are assessed one by one (accept, or push back with reasoning). Accepted fixes go on the **same branch** with tests; then re-verify and request re-review. Only the developer's explicit final approval moves a stage to `APPROVED`. The developer merges into `develop`. After the merge, the agent records `COMPLETED`, updates "Current state", and recommends: **"Start a new Claude Code conversation for the next stage; it should read `CLAUDE.md` and the persisted plan/state."**

---

## S0 — Project foundation

- **Objective / user value:** a buildable, testable shell that every later stage plugs into. Reviewers can clone, open and run with no setup.
- **In scope:** Xcode 26.0 project `MerchantCatalog` (file-system-synchronized folders, bundle id `com.example.MerchantCatalog`, iOS 26.0, Swift 6 language mode, complete strict concurrency, no packages); test target `MerchantCatalogTests` (Swift Testing); `.gitignore`; folder skeleton per [Architecture.md § 2](Architecture.md#2-folder-structure); `ServiceContainerType` + `ServiceContainer` + `AppContext`; `Router`/`Route` + `AppTabView` with Catalog and Saved placeholder tabs; `Log` categories.
- **Out of scope:** networking, analytics, any feature UI.
- **Tests first:**
  - `ServiceContainerTests`: register/resolve, missing → `nil`, overwrite, resolve by protocol type.
  - `RouterTests`: push, pop, pop on empty is a no-op, popToRoot.
  - `NavigationRuleTests`: source scan; `NavigationStack`/`navigationDestination` only in `App/AppTabView.swift`, no `NavigationLink`/`NavigationView`.
  - `AppContextRegistrationTests`: every service type the app resolves is registered.
- **Acceptance:** builds with zero warnings; `xcodebuild test` is green; no third-party dependencies; the build settings show Swift 6 and complete concurrency checking.
- **Manual checks (developer):** launch in the iOS 26 Simulator; both tabs show their placeholder; switching tabs works.
- **Docs:** README setup/run/test verified; CLAUDE.md commands verified; the Architecture folder tree matches reality.

## S1 — Analytics core and diagnostics

- **Objective / user value:** a trustworthy, swappable instrumentation base, so every feature stage ships its events with tests from day one, and reviewers can see events live.
- **In scope:**
  - `AnalyticsTracking` and `AnalyticsProvider` protocols.
  - `AnalyticsService`: implements `AnalyticsTracking`, adds the envelope (timestamp, installation id, session id, sequence), and fans out to providers.
  - `LoggingAnalyticsProvider` and `InMemoryAnalyticsProvider` (DEBUG, bounded).
  - `InstallationIDProvider`; `SessionTracker` (30-minute rule, injected clock/date provider); user properties (set on change); `AnalyticsEvent` lifecycle cases; lifecycle events from `scenePhase`.
  - DEBUG **Diagnostics** sheet: event log with properties, current user properties, recent `OSLogStore` entries, reset installation ID.
- **Events → Active:** `session_started`, `app_foregrounded`, `app_backgrounded`.
- **Tests first:**
  - Installation id is created once and persisted; reset produces a new id.
  - Session rules: cold launch → new session; resume < 30 min → same session; ≥ 30 min → new session; sequence increments and resets per session.
  - Envelope fields are present and typed.
  - Every registered provider receives every event and user-property change. Adding a provider needs no change to `AnalyticsTracking` (spy providers).
  - A user property emits only when its value changes.
  - Scene-phase transitions produce the correct lifecycle events with durations.
  - The in-memory provider drops the oldest entries beyond capacity.
  - `TaxonomyDocumentationTests`: Active events in Analytics.md == `AnalyticsEvent` names in code; Planned names are absent from code.
- **Acceptance:** all tests green and zero warnings; view models and features depend only on `AnalyticsTracking`.
- **Manual checks (developer):** launch, background, foreground; the events appear in Diagnostics and in Console.app (`analytics` category).
- **Docs:** Analytics.md statuses; Architecture § 4/§ 10 if anything changed.

## S2 — Catalog browsing, networking and images

- **Objective / user value:** merchants can browse the full catalog smoothly, with clear loading, empty and error states and images that load only for visible cells.
- **In scope:**
  - **Networking:** `APIClientType` + `URLSessionAPIClient` (own configuration with `urlCache = nil` and `.reloadIgnoringLocalCacheData`; error mapping; request logging); `TargetType`, `HTTPMethod`, `APIConfig` (base URL; DEBUG slow-network `delay`).
  - **Data:** `ProductDTO` + mapping; `ProductsTarget.list`; `ProductRepository` + `LiveProductRepository` (depends on `APIClientType`).
  - **Presentation:** `CatalogListState`, `CatalogViewModel`, and `CatalogView`: a 2-column grid with skeleton, load-more footer, page-error footer, pull-to-refresh, and empty and full-screen error states.
  - **Images:** `ProductCardView` (control layout) and `ProductImageView`, a visibility-gated `AsyncImage` (see [Networking.md § 4](Networking.md#4-image-loading)).
  - Diagnostics: slow-network toggle.
- **Out of scope:** card tap navigation (S4), save button (S5), search/sort (S3), any caching.
- **Events → Active:** `catalog_viewed`, `catalog_load_completed`, `catalog_load_failed`, `catalog_refreshed`, `catalog_page_requested`, `catalog_page_loaded`, `catalog_page_failed`, `retry_requested`.
- **Tests first:**
  - `ProductsTargetTests` (parameterized): path, skip/limit, sort query items; `defaultOrder` sends no `sortBy`.
  - `URLSessionAPIClientTests` with `StubURLProtocol`: 2xx decode, 404, 429, 5xx, timeout, offline, malformed JSON, cancellation → `CancellationError`, the request uses no cache (`cachePolicy`, `urlCache == nil`).
  - `LiveProductRepositoryTests` with `FakeAPIClient`.
  - DTO mapping: optional brand, availability values, image lists.
  - `CatalogListState`: append, de-dup by id, `canLoadMore` at `total`, empty.
  - `CatalogViewModel`:
    - Initial → content; initial → failed → retry → content.
    - Load-more is single-flight; a page failure keeps content; a refresh failure keeps content.
    - No request past the end.
    - Each event fires with the correct properties.
  - Card model exposes the thumbnail URL.
- **Acceptance:** AC-C1 to AC-C5 in [ProductSpecification.md](ProductSpecification.md#41-catalog-browse) are covered by view-model tests; zero warnings.
- **Manual checks (developer):**
  - Scroll to the end: 194 items, no duplicates.
  - Offline launch (Network Link Conditioner at 100 % loss, or the Mac's network off) → error → restore → Retry.
  - The slow-network toggle shows the skeleton and the load-more footer.
  - Image cancellation check from [Networking.md § 4](Networking.md#verification), with the result recorded there.
- **Docs:** Analytics.md statuses; Networking.md manual-check result.

## S3 — Search and sort

- **Objective / user value:** merchants find relevant products fast, and ordering is always truthful across the whole result set.
- **In scope:**
  - `ProductsTarget.search` and debounced search with an injected clock.
  - Generation-based stale-response protection and task cancellation.
  - Separate browse/search list states, with an instant browse restore when search is cleared.
  - A sort control that always shows the current sort; sort applied server-side in both modes.
  - No-results state.
- **Events → Active:** `search_started`, `search_performed`, `search_failed`, `search_cleared`, `sort_changed`. `sort_options_opened` becomes Active **only if** the control exposes a reliable open signal; otherwise remove it from Analytics.md and record why here.
- **Tests first:**
  - Only the last query is requested after 300 ms of inactivity (`TestClock`); whitespace is trimmed; an empty query returns to browse.
  - An out-of-order completion never overwrites newer results (suspended fake repository); a new query cancels the previous task.
  - Search + sort + pagination query items are correct.
  - Clearing restores browse items and sort without a request.
  - A sort change reloads page 1 and fires `sort_changed` only on a real change.
  - `search_started` fires once until the query is empty again.
  - `search_performed` carries length and word count and **no query text**.
- **Acceptance:** AC-S1 to AC-S5 covered by tests; zero warnings.
- **Manual checks (developer):**
  - Fast typing with the slow-network toggle on: one request in the `network` logs, stale responses dropped.
  - Search "phone" with each sort; scroll the results to the end; clear.
- **Docs:** Analytics.md statuses; ProductSpecification if UX details changed.

## S4 — Product details

- **Objective / user value:** merchants can evaluate a product quickly from organized facts.
- **In scope:**
  - `Route.productDetail`; card tap → view-model intent → router.
  - `ProductDetailView`: gallery (visibility-gated images), header, At a Glance, Pricing, Overview, Product information, Shipping & availability, Recent reviews.
  - `ProductInsights` builder; sections omitted when data is missing; state preserved when going back.
- **Events → Active:** `product_selected` (catalog, search), `product_details_viewed`, `product_gallery_interacted`.
- **Tests first:**
  - `ProductInsights` produces only facts present in the data: no brand → no brand row; discount 0 → no discount; availability mapping; MOQ, shipping, return policy, warranty.
  - Section visibility rules.
  - `product_selected` source and position.
  - `product_details_viewed` fires once per push with `content_origin = list`.
  - The gallery event fires once per visit; the gallery model exposes the full image URLs.
  - `NavigationRuleTests` stays green.
- **Acceptance:** AC-D1, AC-D2, AC-C6 covered by tests where testable; zero warnings.
- **Manual checks (developer):** products with 1 and 6 images, with and without brand; going back restores the scroll position; quick VoiceOver pass on details.
- **Docs:** Analytics.md statuses.

## S5 — Saved products

- **Objective / user value:** merchants keep a shortlist across sessions and return to it.
- **In scope:**
  - `SavedProduct` snapshot.
  - `SavedProductsRepository` protocol + `FileSavedProductsRepository`: versioned JSON, atomic writes via an actor, corrupt-file quarantine.
  - `SavedProductsStore`.
  - Save button on cards and in the details toolbar.
  - Saved tab: most recent first, swipe to remove, empty state with "Browse catalog", tab badge.
  - Details opened from Saved: snapshot first, then `/products/{id}`; refresh-failed banner + Retry; "no longer available" on 404; "Price changed since you saved it".
  - `saved_products_count` user property.
- **Events → Active:** `product_saved`, `product_unsaved`, `saved_products_viewed`, `saved_product_revisited`, `product_details_load_failed`; `product_selected` gains `source = saved`.
- **Tests first:**
  - Repository: round trip, ordering, version envelope; a corrupt file is quarantined and the store starts empty.
  - Store: toggle, `isSaved`, count; all surfaces observe one store.
  - `saved_product_revisited` fires only when `savedAt` precedes the session start, once per product per session; `saved_duration_s` is correct.
  - Details from Saved: success; failure (snapshot kept); not found; price changed.
- **Acceptance:** AC-D3, AC-D4, AC-V1 to AC-V4 covered by tests; zero warnings.
- **Manual checks (developer):** save from a card and from details, then check all surfaces; terminate and relaunch; Saved tab offline; swipe to remove.
- **Docs:** Analytics.md statuses; ProductSpecification if snapshot fields changed.

## S6 — Card rating experiment (`product_card_density_v1`)

- **Objective / user value:** a testable product hypothesis with correct assignment and exposure, ready for analysis in a real backend.
- **In scope:**
  - `ExperimentAssigner` (SHA-256 bucketing).
  - `ExperimentService` protocol + `LocalExperimentService` (persisted assignment, DEBUG override).
  - `ExposureTracker` (once per experiment per session).
  - The card renders the rating only in `treatment`, with equal reserved height.
  - Diagnostics override control (Auto / Control / Treatment); `experiment_assignments` user property.
- **Events → Active:** `experiment_exposed`.
- **Tests first:**
  - Assignment: golden bucket values for fixed ids; distribution within 50 % ± 2 % over 10 000 synthetic ids; a persisted assignment is reused.
  - Override precedence and `assignment_source`; resetting the installation id re-buckets.
  - Exposure: once per session for both arms; none without a rendered card; a new session (injected clock) → new exposure.
  - The card model includes the rating only in treatment.
- **Acceptance:** all tests green; zero warnings.
- **Manual checks (developer):** force each variant in Diagnostics, then check the card and that the exposure appears once per session in the event log.
- **Docs:** Experiments.md (any rule changes); Analytics.md statuses.

## S7 — Release readiness

- **Objective / user value:** a coherent, accessible, honestly documented 1.0.
- **In scope:**
  - Accessibility pass: VoiceOver card labels with a save custom action (done in S5, review finding 3; S6 adds the rating to the label), Dynamic Type with a 1-column grid at accessibility sizes, 44 pt targets, dark mode.
  - Final taxonomy reconciliation: every event Active or explicitly removed.
  - README finalized to about one page with the Documentation Index.
  - [AILog.md](AILog.md) completed with real entries; all docs reconciled with the code.
- **Tests first:** card accessibility-label composition (with/without rating, saved/not saved); grid column count by Dynamic Type size.
- **Acceptance:** the release completion criteria in [MasterSpecification.md § 1](MasterSpecification.md#1-product-intent-and-success-definition) are met or explicitly documented as not met.
- **Manual checks (developer):** full smoke checklist (browse, paginate, refresh, offline, search, sort, details, save/unsave, relaunch, Saved offline, experiment overrides, Diagnostics, VoiceOver, largest Dynamic Type).
- **Release:** after approval, the developer merges into `develop` and then `develop` → `main`.

## S8 — Needs attention

Authorized by the developer on 2026-11-14, after the 1.0 release, with a detailed request (summarized here; the request is the scope).

- **Objective / user value:** the main question becomes "Which products need my attention?". Within the first seconds a merchant sees which loaded products are low or out of stock, opens one and sees its stock first.
- **In scope:**
  - Stock status on cards (Out of stock / Low stock / In stock) from one documented policy on `stock`: 0 → out, 1–10 → low, > 10 → in (D-84). List pages also select `stock`.
  - A compact "Needs attention" scope at the top of the list on screen (All products | Needs attention + count), over the products already loaded; it updates as pages load; no extra request (D-85).
  - Details lead with title, price, stock status, category, rating; save stays in the toolbar (D-87).
  - An XCUITest target with a deterministic fixture behind a DEBUG-only `-ui-testing` launch argument (D-88); stable accessibility identifiers.
  - README section: why, the policy, why no inventory/ordering, the fixtures, the next product step.
- **Out of scope (developer's request):** basket, checkout, editing, ordering or restocking, notifications, an inventory dashboard, new tabs, a full-inventory request; analytics, experiments and Diagnostics stay out of the product story.
- **Tests first:** `StockStatusTests` (policy table), DTO/target (`stock` selected and decoded; status from `stock`, not `availabilityStatus`), card model and VoiceOver label, `CatalogViewModelAttentionTests` (count, filter, pagination in the scope, search), details header/insights, saved snapshot without stock, `UITestLaunchTests`, registration. UI tests: launch, needs attention, details, search, save.
- **Acceptance:** all unit and UI tests green through `xcodebuild test`; Debug and Release build with 0 warnings; existing behavior (browse, pagination, refresh, search, sort, saved, offline snapshot, loading/empty/error states) unchanged except where listed.
- **Task plan:** [plans/S8-needs-attention.md](plans/S8-needs-attention.md).

---

## Decisions

| ID | Decision | Made by | Notes |
|---|---|---|---|
| D-1 | Build with Xcode 26.0, deployment target iOS 26.0 | Developer | The brief asks for the current Xcode release (27.2 on 2026-11-13). Updating needs a macOS update that doesn't fit the assignment window. Documented trade-off; re-verify after updating. |
| D-2 | Full master-spec scope | Developer | Chosen to show product orientation (analytics, experiment), knowingly beyond the brief's suggested effort. |
| D-3 | Clean Architecture + MVVM from the developer's previous app, not TCA | Developer | An architecture the developer can explain and extend live. |
| D-4 | Keep `ServiceContainer` + Configurators | Developer | The agent suggested plain init injection; the developer kept the established pattern. |
| D-5 | Moya-style `TargetType` over native `URLSession` (no Alamofire) | Developer | |
| D-6 | `@Observable`, async/await, Swift 6 strict concurrency; structured concurrency first | Developer | Rules in CLAUDE.md § Swift concurrency. |
| D-7 | Swift Testing | Developer | Agent recommendation. |
| D-8 | Two tabs, one stack and router per tab | Developer | Agent recommendation. Reconfirmed at the S2 review (2026-11-13) after comparing it with the developer's previous app's single `NavigationStack` around the tab view: per-tab stacks keep the tab bar visible on push and a back stack per tab. |
| D-9 | Saved items persisted as snapshots in a JSON file | Developer | Instant, offline Saved tab; details always refetch. User data, not a cache. |
| D-10 | **No caching** of any kind: `urlCache = nil`, no custom cache managers | Developer | Replaces the earlier plan (URLCache revalidation + memory image cache). The headers give no useful HTTP caching; custom caching is too much for this scope. |
| D-11 | No computed discounted price | Agent | The API doesn't define whether `price` is before or after the discount. |
| D-12 | Card content follows the experiment definition: no category, discount or availability on cards | Agent | Keeps rating as the single variable. |
| D-13 | Single app target; SPM modules deferred | Developer | |
| D-14 | Feature branches from `develop`, merged into `develop` by the developer; `develop` → `main` at release; branches local; the developer pushes | Developer | |
| D-15 | Master spec committed unchanged as `docs/MasterSpecification.md` | Developer | Evidence of the spec-driven AI workflow. |
| D-16 | README does not report time spent | Developer | |
| D-17 | Consolidated taxonomy (candidate → final mapping in Analytics.md § 4) | Agent | Avoids overlapping events. |
| D-18 | No raw search terms in analytics or logs | Agent | Privacy by default. |
| D-19 | 30-minute session timeout | Agent | |
| D-20 | Installation id in `UserDefaults` (resets on reinstall), not the Keychain | Agent | No cross-install tracking. |
| D-21 | The experiment card reserves equal height in both arms | Agent | Keeps cards per screen constant. |
| D-22 | Sort choice not persisted across launches | Agent | |
| D-23 | `AsyncImage` (no custom image loader), shown only while the cell is visible: load on appear, torn down on disappear | Developer | Replaces the custom `ImageLoader`; the former image-loading stage was folded into S2. **Superseded by D-78** (S7 review). |
| D-24 | Protocol-first infrastructure: `APIClientType`, `AnalyticsTracking` + `AnalyticsProvider`, repository and experiment protocols; only `AppContext` names concrete types | Developer | Swap or add implementations (e.g. another analytics vendor) without changing protocols or callers. |
| D-25 | The agent verifies with build + tests only and never runs the app in the Simulator; the developer does manual Simulator checks | Developer | Token cost. |
| D-26 | `ServiceContainer` keys by `ObjectIdentifier(T.self)` instead of a type-name string | Agent (S0); accepted by the developer | `String(describing:)` keys collide for same-named types in different scopes; `sameNamedTypesInDifferentScopesDoNotCollide` failed against a string-keyed version. |
| D-27 | Registration guard: Configurators expose `resolveDependencies(from:) -> Dependencies?`, used by `make(...)` and by `AppContextRegistrationTests` | Developer (S0) | Chosen over a hand-maintained `requiredServices` list. |
| D-28 | `AppContext.configure()` returns a new context and container per call; no global singleton | Agent (S0) | No global mutable state; isolated containers in tests. |
| D-29 | S0 `Route` has a placeholder case `productDetail(productID: Int)` | Agent (S0) | An uninhabited enum can't be pushed or tested. S4 replaces the payload with `ProductDetailRoute`. |
| D-30 | Universal app (`TARGETED_DEVICE_FAMILY = 1,2`): the phone layout runs on iPad, which supports all four orientations | Developer (S0 review) | The agent proposed iPhone only; the developer chose universal. iPad-specific layouts stay excluded (ProductSpecification § 8). Apple doesn't require iPad support (iPhone-only apps run on iPad in compatibility mode); this is a product choice. |
| D-31 | `SWIFT_DEFAULT_ACTOR_ISOLATION` and `SWIFT_APPROACHABLE_CONCURRENCY` not set | Agent (S0) | Keeps isolation explicit, as Architecture § 5 describes: nonisolated by default, `@MainActor` written on UI-facing types. |
| D-32 | Neutral app icon drawn by `scripts/make-app-icon.swift` (Core Graphics, no dependencies; opaque 1024 px) | Developer (S0 review) | Chosen over reusing the icon of the developer's previous app, which would put another product's brand on this one. |
| D-33 | The analytics stack (`AnalyticsTracking`, `AnalyticsProvider`, `AnalyticsService`, `SessionTracker`, `InstallationIDProvider`, `AppLifecycleTracker`) is `@MainActor`; `track(_:)` is synchronous | Developer (S1 scope) | Agent recommendation, chosen over a `Sendable` service guarded by a lock. All callers are main-actor UI code; event order and sequence numbers stay deterministic; no unstructured tasks. A vendor provider would hop off the main actor inside itself. |
| D-34 | DEBUG "Reset installation ID" simulates a fresh install: new id, new `first_seen_date`, next session `is_first_session = true`, `session_started` (`launch_kind = cold`) sent at once | Developer (S1 scope) | Agent recommendation, chosen over keeping the original `first_seen_date` and first-session flag. |
| D-35 | Sessions and durations use the injected wall clock (`() -> Date`); a negative interval (clock moved back) counts as 0 | Agent (S1) | Timestamps need wall time anyway; one time source keeps tests simple. |
| D-36 | A cold session starts at the first `.active` scene phase or the first tracked event, whichever comes first; one `session_started` either way | Agent (S1) | From S2 on, a view can track before the scene reports `.active`, and every event needs a session id. |
| D-37 | S2's DTO and domain `Product` map only `id`, `title`, `price`, `thumbnail`, `images`, optional `brand` and `availabilityStatus`; S4 adds the details fields with its tests | Developer (S2 scope) | Agent recommendation, chosen over mapping the full product now. Smaller decode surface. |
| D-38 | The catalog empty state's Reload loads page 1 with `trigger: reload` and sends no `retry_requested` | Developer (S2 scope) | Agent recommendation, chosen over reusing `trigger: retry`. Retry outcomes stay paired with `retry_requested`. |
| D-39 | `catalog_viewed` fires on the first display and on each switch back to the Catalog tab (driven by `AppTabView`'s selection); not on popping back from details or returning from the background | Developer (S2 scope) | Agent recommendation, chosen over also re-firing when a new session starts while Catalog is visible. |
| D-40 | `duration_ms` is measured with an injected monotonic `any Clock<Duration>` (`ContinuousClock`; `TestClock` in tests); sessions keep the wall clock (D-35) | Agent (S2) | Latency must not jump with the wall clock; S3's debounce uses the same clock. |
| D-41 | Pull-to-refresh sends only `catalog_refreshed`; it cancels an in-flight page load (dropped by generation) and pauses load-more and the page footer's Retry until it ends; a refresh failure shows a dismissible banner, cleared by the next refresh | Agent (S2) | One event per meaning; one page request in flight. The footer Retry was added after review finding 1. |
| D-42 | DEBUG slow network adds `delay=2000` (ms) to every API request and is persisted in `UserDefaults` (DEBUG only) | Agent (S2) | The skeleton only shows on a first-page load; a persisted toggle makes it checkable at launch. |
| D-43 | `URLError` codes outside Networking.md's table (e.g. `cannotFindHost`) map to `.unknown`; non-2xx other than 404/429 → `.server(status:)`; a non-HTTP response → `.unknown` | Agent (S2) | Follows the documented table without guessing which other codes mean "offline". |
| D-44 | The sort control is a toolbar `Menu` with a `Picker`; `sort_options_opened` is removed from code and Analytics.md | Developer (S3 scope) | Agent recommendation. SwiftUI's `Menu` has no open signal: the iOS 26.0 SDK `SwiftUI.swiftinterface` declares only content/label/`primaryAction` initializers (checked 2026-11-13); `primaryAction` replaces the tap. Chosen over a button opening a confirmation dialog. |
| D-45 | A sort change shows the skeleton until page 1 of the new order arrives; a failure shows the full-screen error. `has_visible_content` = products were on screen when the request started | Developer (S3 scope) | Agent recommendation, chosen over keeping the old order visible during the reload. The label and the order on screen never disagree. |
| D-46 | Sort belongs to each list: a search starts with the sort on screen; a sort change while searching changes only the search; clearing restores browse with its own sort, without a request | Developer (S3 scope) | Agent recommendation (AC-S4), chosen over reloading browse with the newer sort. |
| D-47 | The browse grid stays in the hierarchy, hidden and inert, under the search results; the Catalog title is inline and the search field always visible | Developer (S3 scope) | Agent recommendation, chosen over remembering a card and scrolling back. Exact scroll position on clear. With two scroll views a large title might track the hidden one (expected, not verified). |
| D-48 | Search events use their own trigger (`typing`, `retry`, `sort_change`). A search pull-to-refresh sends only `catalog_refreshed` (`list_context: search`); search pages use `catalog_page_*` with `list_context: search`; their footer Retry is `failed_surface: catalog_page` | Agent (S3) | Same rules as browse (D-41). |
| D-49 | `query_length` = characters of the trimmed query; `word_count` = whitespace-separated words; `had_results` = the search list on screen had ≥ 1 product; `search_started` / `search_cleared` fire when the trimmed query turns non-empty / empty | Agent (S3) | Defines what Analytics.md left open; whitespace alone is not a search. |
| D-50 | During the 300 ms debounce the current list stays on screen; a committed query shows the skeleton; an edit that leaves the trimmed query unchanged sends nothing | Agent (S3) | A query's results never show under another query once they load. |
| D-51 | A `+` in a query value is sent as `%2B` | Agent (S3) | The API decodes `+` as a space (Networking.md A13); `URLComponents` leaves `+` unencoded (checked with a Swift script, 2026-11-13). |
| D-52 | Task handles per list: `firstPageTask` (browse page 1 from taps), `searchTask` (search page 1), one page ≥ 2 task per list; a hidden list's in-flight load finishes in the background; `itemAppeared(id:in:)` is ignored for the hidden list | Agent (S3) | One request per list at a time; the hidden browse layer can't trigger search pagination. |
| D-53 | The Catalog screen gets its tab's `Router` by injection: `CatalogConfigurator.make(from:router:isTabSelected:)` passes `AppTabView`'s `catalogRouter` to `CatalogViewModel`; a card tap calls `cardSelected(id:in:)` | Developer (S4 scope) | Agent recommendation, chosen over a closure callback or a routing protocol. `AppTabView` still owns no view model; tests use a real `Router`. |
| D-54 | `searchDismissed()` is ignored while a route is on the Catalog stack | Developer (S4 scope) | Agent recommendation (AC-C6): if SwiftUI deactivated the search field on a push to details, the S3 Cancel handling would clear the search. Whether it happens is checked manually. |
| D-55 | The At a Glance rating chip shows the rating only; the 3 reviews appear only under "Recent reviews" | Developer (S4 scope) | Agent recommendation, chosen over "rating · 3 reviews": the aggregate rating isn't based on the 3 returned reviews (ProductSpecification § 6). |
| D-56 | `product_details_viewed` sends no `is_saved` until S5 | Developer (S4 scope) | Agent recommendation, chosen over a constant `false`. |
| D-57 | `ProductDetailRoute` = the list's `Product` + `source`; `Product` is `Hashable`. No `ProductsTarget.detail`, details Retry or `FailedSurface.details` in S4 | Agent (S4) | Details from a list need no request (A7); the fetch, its Retry and the saved snapshot arrive with S5, which extends the route. **Updated by D-81.** |
| D-58 | Numbers are shown as the API gives them: rating and discount with up to 2 fraction digits ("4.94", "−7.17%"); weight and dimensions without units | Agent (S4) | The API gives no units (A14); a whole-percent discount would show "−0%" for 0.04 %. |
| D-59 | `product_details_viewed` fires at the details view's first appearance, once per view model (one per push); `product_gallery_interacted` at the first page change away from the shown image, once per view model. `category` = the API slug; `availability` omitted when unknown | Agent (S4) | Tab switches and re-appearances don't re-send; a new push builds a new view model. |
| D-60 | The card's save button is a sibling overlay at the thumbnail's top-trailing corner (`ZStack` with the card `Button`), not nested in the card `Button` | Developer (S5 scope) | Agent recommendation, chosen over a button inside the card label (nested buttons don't take taps reliably) and a context menu only. VoiceOver sees two elements per card until S7 merges them with a custom action. **Updated at the S5 review** (finding 3): each card is already one VoiceOver element with a save custom action; the visible button stays a separate touch target. |
| D-61 | Tab switching goes through `TabSelection` (`@MainActor @Observable`), owned by `AppTabView` and injected into `SavedViewModel` through `SavedConfigurator`; `AppTab` moves to `Core/Navigation` | Developer (S5 scope) | Agent recommendation, chosen over a closure. Same pattern as the router (D-53). |
| D-62 | `ProductDetailRoute` is an enum: `.list(Product, source:)` (catalog, search) or `.saved(SavedProduct)` | Developer (S5 scope) | Agent recommendation, chosen over a struct with optional product and snapshot, which allows invalid combinations. **Updated by D-83.** |
| D-63 | Details opened from Saved send `product_details_viewed` at the first appearance (D-59) with `content_origin: snapshot`; `availability`, `has_discount` and `image_count` are omitted (the snapshot lacks them); the `network` value is removed | Developer (S5 scope) | Agent recommendation, chosen over waiting for `/products/{id}`. `network` can't occur: list items render the list's product (A7), Saved renders the snapshot first. **Updated by D-81.** |
| D-64 | `saved_product_revisited` is derived inside `AnalyticsService` from `product_details_viewed`, which carries the product's `savedAt` (sent only as `is_saved`): when `savedAt` precedes the current session's start, once per product per session id | Developer (S5 scope) | The agent recommended a separate tracker service; the developer chose `AnalyticsService`. Carrying `savedAt` on the event keeps the service independent of the saved store. |
| D-65 | A saved-products file that isn't valid JSON is quarantined (`saved-products.corrupt-<timestamp>.json`); a file with an unknown `version` is left in place; both log `.error` and start empty | Developer (S5 scope) | The agent recommended quarantining both. With an unknown version, the first save overwrites the file. |
| D-66 | Snapshot price persisted as a decimal string, `savedAt` as ISO 8601 with milliseconds; the store loads once at launch (app root `.task`), keeps changes made before the load finishes (merged, ids touched first win) and chains its writes so they land in order | Agent (S5) | Exact prices; no lost save at launch; no stale file after fast toggles. |
| D-67 | Details from Saved: the snapshot shows header, rating and price, no gallery (the gallery never uses the thumbnail); fresh data never overwrites the stored snapshot; a 404 keeps the snapshot with "This product is no longer available." and no Retry; the price note compares with the snapshot the route opened | Agent (S5) | "Price when saved" stays the price when saved; a 404 is final. |
| D-68 | `product_selected` from Saved has no `sort`; `product_saved` omits `category` when unknown; `saved_duration_s` = whole seconds and `days_since_saved` = whole 24-hour periods, both 0 if the clock moved back | Agent (S5) | Defines what Analytics.md left open, like D-35. |
| D-69 | `product_card_density_v1` is resolved once per launch: the cards, `experiment_exposed` and `experiment_assignments` use that assignment until the app restarts. The DEBUG override and the reset's re-bucketing are persisted at once and apply at the next launch | Developer (S6 scope) | Agent recommendation, chosen over a live switch, which could show one variant while the session's exposure reported the other. Diagnostics says "Changes apply at the next launch." |
| D-70 | `CatalogConfigurator` builds a `CardExperiment` value (launch assignment + `ExposureTracker`) for `CatalogViewModel`; its feeds build `ProductCardModel(product:variant:)`, and `itemAppeared(id:in:)` reports exposure after its hidden-list guard (`browse` → `catalog_grid`, `search` → `search_grid`) | Developer (S6 scope) | Agent recommendation, chosen over a separate presenter beside the view model, which would repeat the hidden-list rule (D-47, D-52) in the view. |
| D-71 | The treatment card shows "★ 4.9": the rating with one fraction digit, like the VoiceOver label; control lays out a hidden placeholder row of the same height (D-21) | Developer (S6 scope) | Agent recommendation, chosen over two digits as on details (D-58). 4.96 shows as "5.0". |
| D-72 | DEBUG "Reset installation ID" clears stored assignments and keeps the override | Developer (S6 scope) | Agent recommendation: the override is a developer setting, stored separately (Experiments.md). |
| D-73 | Bucketing input is `UUID.uuidString` (uppercase, as the envelope sends it), and the first 8 digest bytes are read big-endian. Every experiment is resolved at launch in `AppContext`, so `experiment_assignments` is set every launch. A stored value that isn't a known variant is re-bucketed | Agent (S6) | Experiments.md left the case and byte order open; golden values were computed independently with Python `hashlib`. |
| D-74 | Exposure dedup reads the session id after tracking, so an exposure that starts the cold session counts for it. A session that starts while cards are already on screen (resume after 30 min) is exposed at the next card appearance | Agent (S6) | Exposure means a card rendered (`onAppear`), not that the app came back. |
| D-75 | The catalog grid (and its skeleton) has one column at every accessibility text size (`DynamicTypeSize.isAccessibilitySize`, AX1–AX5) and two otherwise; `CatalogLayout.columnCount(for:)` is the tested rule, the views read `@Environment(\.dynamicTypeSize)` | Developer (S7 scope) | Agent recommendation, chosen over keeping two columns at AX1–AX2. |
| D-76 | 44 pt targets: standalone bordered buttons (catalog Reload, Clear search, Retry, page-footer Retry; Saved's Browse catalog; the details banner's Retry) use `.controlSize(.large)`; the refresh banner's close button puts its 44 × 44 pt frame inside the label, like the card's bookmark. Toolbar buttons keep the system's sizing | Agent (S7) | A frame around a button grows its layout, not its hit area (expected SwiftUI behavior, not measured); the large control size is the system's own taller button. Checked manually with Accessibility Inspector, no unit test (no view tests). |
| D-77 | The four open questions carried since S2–S5 are closed with the behavior kept as built: other `URLError` codes stay `.unknown` (D-43); the short sort labels stay at the toolbar's leading edge (D-44); categories show as the API slug in words ("Mens Shirts"); the snapshot's price row on details from Saved stays "Price" under the "Saved information · Saved …" note (D-67). README lists them as known limitations | Developer (S7 scope) | Agent recommendation, chosen over changing any of them in the release stage. |
| D-78 | Product images load through `ImageLoading` (`URLSessionImageLoader`: own `URLSession`, `urlCache = nil`, `@concurrent` download and decoding, `network` log lines) from `ProductImageView`'s `.task(id: url)`: SwiftUI starts it on appear and cancels it on disappear or a URL change, which cancels the request; `ProductImageModel` keeps the placeholder after a cancellation and drops late results; `reset()` on disappear releases the image. The loader is registered as `any ImageLoading` and injected through the SwiftUI environment (`\.imageLoader`, default fails visibly). Replaces `AsyncImage` (D-23) | Developer (S7 review) | The developer asked for real cancellation on fast scrolling: `AsyncImage` offers no way to cancel or observe its request. Trigger (appear/disappear over scroll visibility) and injection (environment over passing through models) were the agent's recommendations, accepted. |
| D-79 | The search keyboard can be put away without ending the search: starting to scroll a catalog grid in either direction (`.onScrollPhaseChange` → `.interacting`; the system's `.scrollDismissesKeyboard` is `.never`) or the keyboard's Search key (`.onSubmit(of: .search)`) drops the field's focus (`.searchFocused`) inside `withAnimation`, never `isSearchPresented`, so the query, results and sort stay and only Cancel ends the search. The Search key doesn't run the search early | Developer (S7 review) | The developer reported that the keyboard couldn't be dismissed while searching and chose this over scroll-only (keyboard stuck on the non-scrolling no-results and error states) and a keyboard "Done" toolbar. Whether dropping focus keeps the search active is expected (as with `UISearchController`), not verified: manual check. **Animated** at the developer's request (2026-11-14): `.immediately` hid the keyboard without animation; the developer chose "any scroll, animated" over interactive dismissal (keyboard following the finger, only when dragging down onto it). |
| D-80 | DEBUG builds log every request and response field in the `network` category (`NetworkLogFormatter`): query, headers, timeout, body; status, type, size, headers, body. **Format (revised 2026-11-14):** API requests as a framed REQUEST box at the start and a RESPONSE box at the end; image requests as one line when they end; boxes split at line breaks into messages ≤ 800 UTF-8 bytes (the unified log cuts at ~1 KB, measured); JSON pretty-printed. Still redacted: `q` (D-18), credential headers, JSON values under keys containing "email". Release keeps the one-line summaries | Developer (S7 review) | The developer asked for full network logging and chose DEBUG only, full chunked JSON and keeping `q` private (agent recommendations). The email redaction was added by the agent: product JSON carries `reviews[].reviewerEmail`, which ProductSpecification § 4.3 says is never logged. |
| D-81 | List and search pages request only `ProductSummary` fields (`select=title,price,thumbnail,rating,category`); details always load `/products/{id}`. From the catalog or search the header shows at once from the summary with a gallery skeleton (since 2026-11-14 follow-up; first "Loading details…"), a failure keeps it with "Couldn't load details" and Retry (404: no longer available), and `product_details_viewed` is sent when the full product arrives (`content_origin: network`, all properties; none if the request fails or the user leaves). From Saved unchanged (snapshot first, event at first appearance, D-63). Supersedes D-57's "no request from a list" | Developer (S7 review) | The developer wanted lists to download only what they show, since most listed products are never opened. Header-first loading, banner + Retry and the S7 branch were the agent's recommendations; the developer chose sending the view event after the fetch over at first appearance. Agent's calls: a separate `ProductSummary` type (every `Product` detail field is optional, so a slim item would pass for a product without details), Saved's event unchanged (offline revisits keep counting, D-64), the `list` value of `content_origin` replaced by `network`. Design: [plans/S7-list-summaries.md](plans/S7-list-summaries.md). **Updated by D-83.** |
| D-82 | `SavedProduct` = `summary: ProductSummary` + `savedAt` (no own copies of the fields); `ProductDetailRoute.summary` gives details the same piece of data from a list and from Saved. The saved file format is unchanged (flat version-1 fields), so no migration | Developer (S7 review) | The developer asked for saved products to carry the same data set that goes from the catalog to details, reusable when opening from Saved. Agent's calls: keep the route enum (D-62) with a shared `summary`, no forwarding properties on `SavedProduct`, and keep the file format. **Updated by D-83.** |
| D-83 | Details open by id: `ProductDetailRoute { productID, source }` for every source. The whole screen is a skeleton (the real layout over `Product.detailPlaceholder`, redacted and pulsing, the gallery square with a spinner) until `/products/{id}` returns; no list data is shown. Catalog/search failure: full-screen error with Retry (404: no longer available). Saved failure: the snapshot found in the store by id, with the banner and Retry (option A). `product_details_viewed` fires when content first shows: the full product (`network`, any source) or Saved's snapshot fallback (`snapshot`). The bookmark is enabled once something can be saved, or when the product is already saved | Developer (S7 review) | The developer saw the summary data on details as noise and chose option A for Saved (keep offline details). Agent's calls: the view-event rule, the placeholder-based skeleton, the bookmark rule, a cancelled Retry returning to its failure. Supersedes D-62's enum, D-81's header-first loading and D-82's `route.summary`. Design: [plans/S7-details-by-id.md](plans/S7-details-by-id.md). |

| D-84 | Stock status is derived from `stock` by one policy, `StockStatus(stock:)` (`Shared/Products/Domain`): ≤ 0 → Out of stock, 1–10 → Low stock, > 10 → In stock, missing → no status. Cards, Needs attention, details and the `availability` analytics property all use it; the API's `availabilityStatus` is no longer decoded. List and search pages add `stock` to `select` | Agent (S8), within the developer's request | The request allowed `availabilityStatus` only if the current decoder supports it: the list decoder doesn't (D-81 selects summary fields). The API's value also disagrees with `stock`: of 194 products, 10 with stock 7–10 are "In Stock" while other products with stock 7 are "Low Stock" (curl `/products?limit=0&select=stock,availabilityStatus`, 2026-11-14; A16). One rule keeps the card, the attention list and details consistent. |
| D-85 | Needs attention is a scope of the list on screen (browse or search): two chips at the top of the grid, "All products" and "Needs attention" with the count of loaded products that are low or out of stock. The scope filters only what is loaded, in server order; in it, cards don't trigger automatic paging and the footer says what the count is based on ("Based on 20 of 194 products loaded so far.") with **Load more products**. No extra request | Agent (S8), within the developer's request | Chosen over a separate section above "All products", which would show each attention product twice in one scroll view (duplicate identifiers, double exposure) and push the catalog down. Automatic paging is off in the scope because the filtered list's end isn't the loaded list's end. |
| D-86 | Cards show a compact stock row under the price in **both** experiment arms; the card's VoiceOver label reads it after the price. Supersedes D-12's "no availability on cards" | Agent (S8), within the developer's request | The rating stays the experiment's only difference; Experiments.md records the layout change so data from before and after S8 isn't pooled. |
| D-87 | Details lead with title, price, stock status (badge), category · brand, rating; At a Glance drops rating and availability (now in the header); Pricing drops the price row (discount and the price-changed note remain; the section is omitted without them); Shipping & availability shows the derived status and the stock count | Agent (S8), within the developer's request | The request's priority order; avoids showing the same fact three times. |
| D-88 | UI tests: XCUITest target `MerchantCatalogUITests`. The `-ui-testing` launch argument (DEBUG builds only) configures `AppContext` with a `FixtureProductRepository` (4 products: in, low, out, in stock; no images), a fresh `UserDefaults` suite and a fresh temporary saved-products folder. Production networking and Release builds are unchanged | Agent (S8), within the developer's request | Deterministic and offline. The card experiment's variant isn't pinned (a fresh installation is hashed); the tests don't read the rating and both arms have the same card height (D-21). |
| D-89 | A saved snapshot keeps no stock count: `SavedProductsStore.save` drops it, the file format is unchanged, and Saved's offline fallback shows no stock status | Agent (S8) | A stock count from when the product was saved would read as current. |

Decisions marked "Agent" are open to the developer's override during plan review.

## Review log

*(One entry per stage at each review gate: branch, head commit, changed files, tests, build warnings, manual checks for the developer and their results, limitations, open questions, findings and their resolution.)*

### S0 — Project foundation · READY_FOR_REVIEW (2026-11-13)

- **Branch:** `feature/project-foundation` (from `develop` at `a8f777c`). **Head:** the `docs: record S0 review gate` commit on top of `0bb389d`.
- **Commits:** `ba5bb76` task plan · `54bd657` Xcode project skeleton · `9c3551b` ServiceContainer · `0a838c2` AppContext · `58ca818` Router, Route, Log · `0bb389d` AppTabView + navigation rule · review-gate docs.
- **Changed files:**
  - Project: `MerchantCatalog.xcodeproj` (objectVersion 77, file-system-synchronized folders, shared `MerchantCatalog` scheme, test target not parallelized), `.gitignore`.
  - App: `App/{MerchantCatalogApp, AppContext, AppTab, AppTabView}.swift`, `Core/DI/{ServiceContainerType, ServiceContainer}.swift`, `Core/Navigation/{Route, Router}.swift`, `Core/Logging/Log.swift`, `Assets.xcassets`.
  - Tests: `App/{AppContextRegistrationTests, NavigationRuleTests}.swift`, `Core/DI/ServiceContainerTests.swift`, `Core/Navigation/RouterTests.swift`.
  - Docs: `docs/plans/S0-project-foundation.md`, Architecture § 2/5/6/7/12, README (status, run/test), CLAUDE.md (commands verified), AILog, this file.
- **Build settings** (`xcodebuild -showBuildSettings`, both targets): `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, bundle ids `com.example.MerchantCatalog` / `com.example.MerchantCatalogTests`. No packages.
- **Build:** `xcodebuild … clean build` (Debug, iPhone 17, iOS 26.0 Simulator) succeeded. Result bundle: **0 warnings**, 0 errors, 0 analyzer warnings. The raw log has one `appintentsmetadataprocessor` line, "warning: Metadata extraction skipped. No AppIntents.framework dependency found.", which is a tool message and is not counted as a build issue.
- **Tests:** `xcodebuild … test`: **13 passed, 0 failed, 0 skipped** in 4 suites: `ServiceContainerTests` 5, `RouterTests` 6, `AppContextRegistrationTests` 1, `NavigationRuleTests` 1. Each suite was seen failing for the expected reason first (compiling stubs; a string-keyed container; a shared-singleton `AppContext`; no `AppTabView`).
- **Manual Simulator checks for the developer** (the agent did not run the app):
  1. Open `MerchantCatalog.xcodeproj` in Xcode 26.0: it opens without errors or an "Update to recommended settings" prompt, the `MerchantCatalog` scheme is available, and `MerchantCatalog/` and `MerchantCatalogTests/` show as folders. The project file was written by hand and has only been used through `xcodebuild`.
  2. Run on an iOS 26 iPhone simulator: the Catalog tab shows the "Catalog" title and the "Products will appear here." placeholder.
  3. Switch to Saved ("Saved products will appear here."), then back to Catalog: switching works and the tab bar stays visible.
  4. ⌘U in Xcode: 13 tests pass.
  5. Optional: in Console.app, filter on subsystem `com.example.MerchantCatalog`. "App launched" appears (`lifecycle`); with debug messages enabled, tab switches log "tab saved" / "tab catalog" (`navigation`).
- **Known limitations:**
  - `AppContextRegistrationTests` only checks container isolation; per-Configurator checks start in S2.
  - `forceResolve`'s trap is untested (exit tests aren't supported on iOS).
  - `NavigationRuleTests` is a plain token scan: it also matches comments (two doc comments were reworded to "navigation stack"), and it doesn't cover `NavigationSplitView`.
  - `Route` and its destination are placeholders until S4. `MerchantCatalogApp` holds the `AppContext` but nothing resolves from it until S2.
  - `AppIcon` is empty, so the app shows the default icon. Only the Debug configuration was built.
- **Open questions:**
  1. iPhone only (D-30): keep, or also allow iPad with the phone layout?
  2. App icon: add one (S7?) or keep the default?
  3. The planning AILog row calls the container "string-keyed"; S0 keys by `ObjectIdentifier` (D-26). OK?
- **Findings and resolution:** awaiting the developer's Codex review.

#### S0 follow-up — developer answers to the open questions (2026-11-13)

- **Answers:** (1) make the app universal (D-30); (2) add a neutral generated icon now (D-32); (3) keep the `ObjectIdentifier` key (D-26 accepted).
- **Changes:** `c8b88bf` sets `TARGETED_DEVICE_FAMILY = 1,2`, adds the iPad orientations (all four), adds `AppIcon.png` and `scripts/make-app-icon.swift`. A docs commit follows (decisions, AILog, Architecture, task plan).
- **Re-verification:**
  - `xcodebuild … clean build`: succeeded; result bundle **0 warnings**, 0 errors, 0 analyzer warnings (same `appintentsmetadataprocessor` tool line as before).
  - The built `Info.plist` has `UIDeviceFamily` = [1, 2] and iPad icon entries (`CFBundleIcons~ipad`).
  - `sips`: the icon is 1024 × 1024, RGB, `hasAlpha: no`.
  - `xcodebuild … test`: **13 passed, 0 failed, 0 skipped**.
- **Added manual checks for the developer:**
  6. The home screen shows the new icon (teal-to-navy gradient, 2×2 grid, top-right tile amber).
  7. Run on an iOS 26 iPad simulator: both tabs show their placeholders, switching works, and rotating to each orientation keeps the layout intact.
- **Open questions:** none left from the first gate.

#### S0 review result (2026-11-13)

- Independent Codex review, run manually by the developer: **approved**. No findings were shared with the agent.
- Developer's final approval: **approved**. The developer also authorized S1.
- Status → `APPROVED`. The S1 conversation records `COMPLETED` once it confirms that `feature/project-foundation` is merged into `develop`.

#### S0 merge (recorded by the S1 conversation, 2026-11-13)

- `git branch --merged develop` lists `feature/project-foundation`; `develop` and the branch both point at `ee150e0`. Status → `COMPLETED`.
- The merge was a fast-forward, so `develop` has no merge commit for S0. The git-flow section above suggests `--no-ff`; the developer decides whether that matters for later stages.

### S1 — Analytics core and diagnostics · READY_FOR_REVIEW (2026-11-13)

- **Branch:** `feature/analytics-core` (from `develop` at `ee150e0`). **Head:** the `docs: record S1 review gate` commit on top of `93e36b3`.
- **Scope confirmed by the developer** (2026-11-13): as planned; analytics stack `@MainActor` and synchronous (D-33); the DEBUG reset simulates a reinstall (D-34). Agent decisions D-35 (wall-clock sessions) and D-36 (cold session at the first `.active` or the first event).
- **Commits:** `dca80e0` S0 completed / S1 in progress · `e313e5e` task plan + D-33–D-36 · `88d0513` event model + taxonomy test (lifecycle events → Active) · `0ddacd1` InstallationIDProvider · `ef4a426` SessionTracker · `2ddcae9` AnalyticsService · `0b9752a` lifecycle events from scene phases · `66ecdd0` launch user properties · `8a1e097` logging + in-memory providers · `b9e24a9` AppContext + scene-phase wiring · `93e36b3` DEBUG Diagnostics sheet · review-gate docs.
- **Changed files:**
  - App: `App/{AppContext, MerchantCatalogApp, AppTabView, AppPhase+ScenePhase}.swift`; `Core/Analytics/{AnalyticsValue, AnalyticsEvent, AnalyticsEnvelope, AnalyticsTracking, AnalyticsProvider, AnalyticsService, UserProperty, AppInfo, InstallationIDProvider, SessionTracker, AppLifecycleTracker}.swift`, `Core/Analytics/Providers/{LoggingAnalyticsProvider, InMemoryAnalyticsProvider}.swift`; `Core/Logging/{Log, LogStoreReader}.swift`; `Features/Diagnostics/Presentation/{DiagnosticsView, DiagnosticsViewModel, DiagnosticsConfigurator}.swift`. DEBUG-only: the in-memory provider, the log reader and Diagnostics.
  - Tests: `Core/Analytics/*Tests.swift` (9 suites), `Features/Diagnostics/DiagnosticsViewModelTests.swift`, `App/{AppContextRegistrationTests, AppPhaseTests}.swift`; `Fakes/{SpyAnalytics, SpyAnalyticsProvider, FakeLogReader}.swift`; `Support/{RepositoryFiles, IsolatedDefaults, TestNow, TestUUIDs}.swift`. `NavigationRuleTests` now uses the shared `RepositoryFiles` helper (no behavior change).
  - Docs: `docs/plans/S1-analytics-core.md`, Analytics.md (three lifecycle events Active; § 2 session, envelope, reset and user-property details), Architecture § 2/4/5/6/10, README status, AILog, this file.
- **Build settings** (`xcodebuild -showBuildSettings`, 2026-11-13): unchanged from S0 (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation). No packages.
- **Build:** `xcodebuild … clean build` (Debug, iPhone 17, iOS 26.0 Simulator) succeeded. Result bundle: **0 warnings**, 0 errors, 0 analyzer warnings (the raw log again has only the `appintentsmetadataprocessor` "Metadata extraction skipped" tool line). `xcodebuild … -configuration Release build` also succeeded, so the DEBUG-only code compiles out cleanly.
- **Tests:** `xcodebuild … test`: **67 passed, 0 failed, 0 skipped** in 15 suites (result bundle summary). New suites: `AnalyticsEventTests` 2, `TaxonomyDocumentationTests` 3, `InstallationIDProviderTests` 5, `SessionTrackerTests` 6, `AnalyticsServiceTests` 9, `AppLifecycleTrackerTests` 9, `LaunchUserPropertiesTests` 4, `LoggingAnalyticsProviderTests` 2, `InMemoryAnalyticsProviderTests` 3, `AppPhaseTests` 1, `DiagnosticsViewModelTests` 6; `AppContextRegistrationTests` grew from 1 to 5. Counts are test functions; parameterized ones run more cases.
- **Red first:** `SessionTracker`, `AnalyticsService`, `AppLifecycleTracker`, both providers, `DiagnosticsViewModel` and `DiagnosticsConfigurator` failed on assertions against compiling stubs. The event model, `InstallationIDProvider`, `AppInfo`, `AppPhase` mapping and the AppContext registrations failed on compilation first. `TaxonomyDocumentationTests` was also seen failing on a deliberate doc mismatch (one event set back to Planned). `UserProperty` and `AnalyticsEnvelope.fields` formatting were written together with the service stub, so their assertions were not seen failing on their own.
- **Manual Simulator checks for the developer** (the agent did not run the app):
  1. Run the Debug build on an iOS 26 iPhone simulator. The Catalog tab has a Diagnostics button (stethoscope) at the top right; the Saved tab has none.
  2. Open Diagnostics. Installation ID and Session ID show UUIDs. User properties: `app_version` 1.0, `build_number` 1, `device_model` = the simulated model (e.g. `iPhone18,3`, not `arm64`), `first_seen_date` = today's UTC date, `is_debug_build` true, `os_version` 26.0. Events: `session_started #1` with `launch_kind: cold` and `is_first_session: true` on the first launch after install.
  3. Close the sheet, go Home (⇧⌘H), wait ~10 s, reopen the app, open Diagnostics: `app_backgrounded #2` (`foreground_duration_s`) and `app_foregrounded #3` (`background_duration_s` ≈ the wait), same Session ID.
  4. Pull down Control Center or open the app switcher and return without leaving the app: no new events.
  5. Terminate the app and relaunch: same Installation ID, new Session ID, `session_started #1` with `is_first_session: false`.
  6. Tap "Reset installation ID": the Installation ID and Session ID change; the newest event is `session_started #1` with `is_first_session: true`, `launch_kind: cold`.
  7. Recent logs: shows the app's entries from the last hour (e.g. "App launched", "scene phase active", "session started (cold)"); pull to refresh. Debug-level lines (`analytics`, `navigation`) are expected to be missing here. Please record what actually appears.
  8. Console.app: select the simulator, filter subsystem `com.example.MerchantCatalog`, category `analytics`, enable Action → Include Debug Messages. Expect lines like `event session_started #1 session <uuid> {is_first_session=false, launch_kind=cold}` and `user property app_version: nil → 1.0`.
  9. Optional: stay in the background for 30 minutes or more, then reopen: a new Session ID with `session_started` (`launch_kind: resume`) before `app_foregrounded`. The rule is unit-tested; this checks the real scene-phase sequence.
  10. Optional: on an iPad simulator, the Diagnostics sheet opens and dismisses with Done.
  11. ⌘U in Xcode: 67 tests pass.
- **Known limitations:**
  - The real scene-phase sequence at launch and on backgrounding is expected, not verified by the agent. The tracker ignores repeats, `.inactive` and a `.background` before the first `.active`, so either launch order gives one cold `session_started` (unit-tested); checks 2–5 confirm it on device.
  - The app observes the app-wide `scenePhase`. On iPad with several windows, `app_backgrounded` fires only when every window is in the background. Multi-window behavior was not checked.
  - What `OSLogStore` returns (and that debug-level entries are missing) is expected platform behavior, recorded in check 7, not tested.
  - User-property change detection is in memory: each launch re-sends the launch properties, and the DEBUG reset re-sends only `first_seen_date` under the new id. A real vendor integration would re-identify after a reset.
  - The in-memory event log keeps the latest 500 events and is empty after relaunch. The reset doesn't clear experiment assignments yet (S6).
  - Sessions use the wall clock (D-35). Changing the device clock can shorten or lengthen a measured gap; negative gaps count as 0.
  - Nothing tracks before the first `.active` yet, so the early-event path of D-36 is covered by unit tests only.
- **Open questions** (answered by the developer, 2026-11-13):
  1. Merge style: S1 is merged into `develop` with `--no-ff`, as the git-flow section says. S0 stays fast-forward (no history rewrite).
  2. `app_version`: keep `MARKETING_VERSION = 1.0`; no build-setting change.
- **Findings and resolution:** awaiting the developer's Codex review.

#### S1 review result (2026-11-13)

- The developer reported S1 **approved**. No Codex findings or manual-check results were shared with the agent.
- Status → `APPROVED`. The developer merges `feature/analytics-core` into `develop` with `--no-ff`; the next stage's conversation records `COMPLETED` once it confirms the merge. S2 is not authorized yet.

#### S1 merge (recorded by the S2 conversation, 2026-11-13)

- `git branch --merged develop` lists `feature/analytics-core`; the developer merged it with `--no-ff` (merge commit `30838a3`) and wants `--no-ff` merges for later stages too. Status → `COMPLETED`.
- The developer authorized S2 on 2026-11-13.

### S2 — Catalog browsing, networking and images · READY_FOR_REVIEW (2026-11-13)

- **Branch:** `feature/catalog-browse` (from `develop` at `30838a3`). **Head:** the `docs: record S2 review gate` commit on top of `e25b889`.
- **Scope confirmed by the developer** (2026-11-13): as planned; S2 maps only the fields it uses (D-37); the empty state's Reload uses `trigger: reload` (D-38); `catalog_viewed` on tab visibility only (D-39). Agent decisions D-40 (monotonic clock for durations), D-41 (refresh rules), D-42 (persisted 2 s slow network), D-43 (unlisted errors → `.unknown`).
- **Commits:** `8e41c9e` S1 completed / S2 in progress · `30bb25a` task plan + D-37–D-43 · `986c55e` TargetType + ProductsTarget · `b002d47` URLSessionAPIClient · `0f6dc83` product DTO + LiveProductRepository · `b3dc0b5` CatalogListState · `c29167a` catalog analytics events (8 events → Active) · `6b978d8` view model first page · `072a961` pagination · `02be2f7` pull-to-refresh · `973e3cc` catalog grid UI + composition · `e25b889` DEBUG slow-network toggle · review-gate docs.
- **Changed files:**
  - App: `Networking/{APIClientType, APIConfig, AppError, HTTPMethod, NetworkLogger, RequestDelay, TargetType, URLSessionAPIClient}.swift`; `Core/Time/{Clock+Stopwatch, Duration+Milliseconds}.swift`; `Shared/Products/Domain/{Product, ProductPage, ProductRepository, ProductSort}.swift`, `Shared/Products/Data/{ProductDTO, ProductsTarget, LiveProductRepository}.swift`; `Features/Catalog/Domain/CatalogListState.swift`, `Features/Catalog/Presentation/{CatalogView, CatalogViewModel, CatalogPhase, CatalogConfigurator, ProductCardView, ProductCardModel}.swift`; `DesignSystem/Components/{ProductImageView, ErrorBanner}.swift`; `Features/Diagnostics/Domain/SlowNetworkSetting.swift` and the Diagnostics view model, view and Configurator (DEBUG); `Core/Analytics/AnalyticsEvent.swift`; `App/{AppContext, AppTabView}.swift`.
  - Tests: `Networking/{URLSessionAPIClientTests, AppErrorTests, NetworkLoggerTests}`, `Shared/Products/{ProductsTargetTests, ProductDTOTests, LiveProductRepositoryTests}`, `Features/Catalog/{CatalogListStateTests, CatalogViewModelTests, ProductCardModelTests}`, `Features/Diagnostics/SlowNetworkSettingTests`, `Core/Time/ClockStopwatchTests`, `Core/Analytics/CatalogAnalyticsEventTests`; additions to `AppContextRegistrationTests` and `DiagnosticsViewModelTests`; `Fakes/{StubURLProtocol, FakeAPIClient, FakeProductRepository, ProductFixtures}`, `Support/{TestClock, ProductJSON}`, `SpyAnalytics.reset()`.
  - Docs: `docs/plans/S2-catalog-browse.md` (with deviations), Analytics.md (8 events Active; `reload` trigger; D-39/D-41 notes), Architecture § 2/5/6/8/10, Networking.md § 2 (as built, D-43) and § 4 (check pending), README status, AILog, this file.
- **Build settings** (`xcodebuild -showBuildSettings`, 2026-11-13): unchanged (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation). No packages.
- **Build:** `xcodebuild … clean build` (Debug, iPhone 17, iOS 26.0 Simulator) succeeded. Result bundle: **0 warnings**, 0 errors, 0 analyzer warnings (the raw log again has only the `appintentsmetadataprocessor` "Metadata extraction skipped" tool line). `xcodebuild … -configuration Release build` succeeded with 0 warnings and 0 errors in its result bundle, so the DEBUG-only slow-network code compiles out cleanly.
- **Tests:** `xcodebuild … test`: **146 passed, 0 failed, 0 skipped** in 27 suites (result bundle summary). New suites: `URLSessionAPIClientTests` 10, `AppErrorTests` 3, `NetworkLoggerTests` 2, `ProductsTargetTests` 2, `ProductDTOTests` 8, `LiveProductRepositoryTests` 2, `CatalogListStateTests` 6, `CatalogViewModelTests` 29, `ProductCardModelTests` 3, `CatalogAnalyticsEventTests` 3, `ClockStopwatchTests` 3, `SlowNetworkSettingTests` 3; `AppContextRegistrationTests` grew from 5 to 8, `DiagnosticsViewModelTests` from 6 to 8. Counts are test functions; parameterized ones run more cases.
- **Red first:** every new suite failed on compilation first (missing types or members). `AppContextRegistrationTests.networkServicesAreRegistered` and `catalogDependenciesResolve` failed on assertions before `AppContext` registered the services. The no-cache tests were mutation-checked (with the three cache settings removed, `requestUsesNoCache` and `buildsRequestFromTarget` failed). Passed when first run, because the code already existed: `ClockStopwatchTests.wholeMilliseconds` (helper written in the client task) and `slowNetworkSettingReachesTheAPIClient` (a wiring guard added after the wiring). Within a suite, tests added in the same batch were seen failing together on compilation, not one by one on assertions.
- **Manual Simulator checks for the developer** (the agent did not run the app):
  1. Run the Debug build on an iOS 26 iPhone simulator. The Catalog tab shows a grey skeleton grid briefly, then 20 products in 2 columns: square image, title (up to 2 lines), price in USD. The Diagnostics button is still at the top right.
  2. Open Diagnostics. Events (newest first): `catalog_load_completed` (`trigger: initial`, `sort: default_order`, `result_count: 20`, `total_count: 194`, `duration_ms`), `catalog_viewed` (`sort: default_order`, `list_context: browse`) and `session_started #1` (cold). There must be exactly **one** `session_started`: `catalog_viewed` can now be tracked before the scene reports `.active` (the D-36 early-event path, unit-tested only until now). Please record the order you see.
  3. Scroll slowly to the end: a spinner footer appears while each page loads; the list ends with "You've reached the end" after **194** products with no duplicates (e.g. the last products are ids 191–194 in API order). Events `catalog_page_requested` / `catalog_page_loaded` run `page_index` 2…10; the last `catalog_page_loaded` has `has_more: false`. Scrolling further makes no request (Console `network`).
  4. Offline launch: turn the Mac's network off (or Network Link Conditioner 100 % loss), terminate and relaunch. Expect the full-screen error with Retry: "You're offline…" with the network off, or "This is taking too long…" after 15 s with 100 % loss. Restore the network, tap Retry: the grid loads; events `retry_requested` (`failed_surface: catalog`) then `catalog_load_completed` (`trigger: retry`). If the network-off case shows "Something went wrong. Try again." instead, please note the error code from the `network` log (see open question 1).
  5. Page error: load page 1, turn the network off, scroll to the bottom: the footer shows the error message and Retry, page 1 stays. Restore, tap Retry: the next page appends (`retry_requested` with `failed_surface: catalog_page`, then `catalog_page_requested` with `is_retry: true`).
  6. Pull to refresh with the network on: the grid never blanks; `catalog_refreshed` (`result: success`). With the network off: content stays, a banner with the message and a close button appears over the grid; `catalog_refreshed` (`result: failure`, `error_type`). The close button hides it; the next pull also clears it.
  7. Slow network: Diagnostics → Network → turn on "Slow network", terminate and relaunch: the skeleton stays about 2 s. Scroll to the end of the loaded page: the spinner footer stays about 2 s. The Console `network` lines show `delay=2000`. Turn it off afterwards (it persists).
  8. Tabs: switch to Saved and back several times: exactly one new `catalog_viewed` per switch back (none missing, none doubled; this checks that the hidden Catalog tab receives `isTabSelected = false`), the scroll position is kept, no reload. Opening and closing Diagnostics sends no `catalog_viewed`.
  9. Image cancellation check from [Networking.md § 4](Networking.md#verification) (Network Link Conditioner "3G", a proxy or Instruments; scroll fast): requests for cells that left the screen should end as cancelled. Please record the date, method and result there.
  10. Console.app, subsystem `com.example.MerchantCatalog`, category `network`, debug messages included: lines like `[a1b2c3d4] GET https://dummyjson.com/products?limit=20&skip=0` and `[a1b2c3d4] 200 in 312 ms, 48213 bytes`. Category `performance`: `catalog first page (initial) in … ms`.
  11. Optional: dark mode and an iPad simulator: the skeleton, cards and banner stay readable; the grid has 2 columns on iPad too (iPad-specific layouts are excluded).
  12. ⌘U in Xcode: 146 tests pass.
- **Known limitations:**
  - `AsyncImage` cancellation on disappear is expected, not verified (check 9). The tab-visibility signal, `.task` cancellation on tab switch and the scroll-position retention are expected SwiftUI behavior, checked manually (checks 2, 8), not by unit tests.
  - Load-more fires from the `onAppear` of the last 5 cards. If those cards are already on screen when load-more becomes possible again (e.g. right after a refresh), the next page loads once the user scrolls. There is no automatic retry after a page failure; the footer's Retry is the way back (by design).
  - `has_visible_content` is always `false` in S2: page-1 loads only happen without visible content. It becomes meaningful with S3's sort change.
  - Cards read as "title, price" in VoiceOver; the saved state and save action arrive in S5/S7, the 1-column grid at accessibility text sizes in S7.
  - The refresh banner stays until it is closed or the next refresh starts.
  - `TestClock.sleep` records an issue and throws; S3's debounce implements it.
  - No caching (D-10): scrolling back re-downloads thumbnails, and the catalog needs a connection.
- **Open questions:**
  1. D-43 maps only `notConnectedToInternet`, `networkConnectionLost` and `dataNotAllowed` to "offline". If check 4 shows another code with the network off (e.g. `cannotFindHost` or `cannotConnectToHost`), should those also count as offline?
  2. Task 9 deviated from the plan: `AppTabView` owns the catalog view model (built by `CatalogConfigurator.makeViewModel(from:)`) and reports tab visibility from its root `onChange`, instead of passing `isTabSelected` into `CatalogView`. OK to keep?
- **Findings and resolution:** awaiting the developer's Codex review.

#### S2 follow-up — developer feedback at the gate (2026-11-13)

- **Feedback:** `AppTabView` must not own the catalog view model (open question 2). The developer also asked whether `AppTabView` is a custom tab bar (no: it is the app's root view around the native `TabView`, holding the tab selection, one `Router` and `NavigationStack` per tab, and the Diagnostics sheet flag) and whether the app could use one `NavigationStack` for the whole app, as their previous app does.
- **Decisions:** keep per-tab stacks (D-8 reconfirmed). For the tab signal, the planned `isTabSelected` flag (chosen over reporting `onAppear` from `CatalogView`).
- **Change:** `8dd6d5a`: `CatalogConfigurator.make(from:isTabSelected:)` returns `CatalogView`, which owns its view model in `@State` and sends `catalog_viewed` from `.onChange(of: isTabSelected, initial: true)`; `AppTabView` passes `selection == .catalog` and owns no view model. No view-model behavior changed, so no unit test changed; manual check 8 now also checks that no switch back is missed or doubled.
- **Re-verification:** `xcodebuild … clean build`: result bundle **0 warnings**, 0 errors, 0 analyzer warnings; Release build 0 warnings, 0 errors; `xcodebuild … test`: **146 passed, 0 failed, 0 skipped** in 27 suites.
- **Open questions left:** 1 (offline error codes, D-43).

#### S2 Codex review — findings and resolution (2026-11-13)

The developer ran an independent Codex review and shared four findings. Each was checked against the code and accepted; each fix went in test-first on this branch, as its own commit.

| # | Finding | Assessment | Fix | Tests |
|---|---|---|---|---|
| 1 | P1 — `retryPage()` can start a page request while `refresh()` runs | Accepted. A refresh leaves a failed footer in place; its Retry started a second request (breaking one-request-in-flight) whose page could land after the fresh page 1. | `c9702ea`: `retryPage()` is ignored while refreshing (no request, no `retry_requested`); load-more already was (D-41). | `retryPageIsIgnoredDuringRefresh`: failed before the fix (4 requests and a `retry_requested`), passes after. |
| 2 | P1 — `URLSessionAPIClient` logs `String(describing: error)`, which can contain the request URL and search query | Accepted. A `URLError`'s description includes the failing URL; with S3's search the term would reach the log. | `b43b422`: `NetworkLogger.summary(of:)` logs `URLError <code>`, `DecodingError.<kind> at <path>` or the error's type name; the failure line names the `error_type`. | `urlErrorSummaryOmitsTheURL`, `decodingErrorSummaryNamesThePathOnly`, `otherErrorsAreSummarizedByType`: compile failure first, then pass. |
| 3 | P2 — `ProductDTO.webURL` checks only the scheme | Accepted. `https:foo`, `http:/x`, `https://` and `https:///…` were accepted as image URLs. | `08042d1`: a non-empty host is required. | `urlsWithoutAWebHostAreDropped` (5 cases): the four host-less cases failed before the fix; `ftp://…` was already rejected. |
| 4 | P2 — `CatalogViewModel` keeps unstructured tasks without cancelling them on teardown | Accepted. `[weak self]` was re-acquired for the whole request, so a running task kept the view model alive and could track events after the screen was gone. | `cc2347f`: the tasks fetch through a static helper that doesn't reference the view model, apply the result through `[weak self]`, and an `isolated deinit` cancels both. | `releasingTheViewModelCancelsAPageLoad`, `releasingTheViewModelCancelsARetry`: failed before the fix (the view model stayed alive, the request wasn't cancelled, `catalog_page_loaded` was tracked), pass after. `FakeProductRepository` now counts requests that return to a cancelled task. |

- **Re-verification:** `xcodebuild … clean build`: result bundle **0 warnings**, 0 errors, 0 analyzer warnings; Release build 0 warnings, 0 errors; `xcodebuild … test`: **153 passed, 0 failed, 0 skipped** in 27 suites (146 + 7 new tests).
- **Not verified by tests:** that no other log line contains an error description. Checked by reading: the only remaining `localizedDescription` is the DEBUG Diagnostics log-store error, which is not a network error.
- **Scope:** no change beyond S2. Analytics.md and D-41 mention the footer Retry; Architecture § 5 and § 10 and Networking.md § 2 describe the task lifecycle and error logging as built.
- **Process note:** for the red check of finding 1, the agent briefly used `git stash` on one file, against this shared folder's rules; it was popped at once (`git stash list` is empty). Later red checks didn't use it.

#### S2 review result (2026-11-13)

- Codex re-review of the four fixes, run manually by the developer: **approved**. Developer's final approval: **approved**. No manual-check results were shared with the agent; open question 1 (offline error codes, D-43) stays open until check 4 is run.
- Status → `APPROVED`. The developer merges `feature/catalog-browse` into `develop` with `--no-ff`. The developer also authorized S3; the S3 conversation records S2 `COMPLETED` once it confirms the merge.

#### S2 merge (recorded by the S3 conversation, 2026-11-13)

- The developer merged `feature/catalog-browse` into `develop` with `--no-ff`: merge commit `59415a9` (`git branch --merged develop` lists the branch). S2 → `COMPLETED`. S3 (authorized 2026-11-13) starts from `develop` at `59415a9` on `feature/search-sort`.

### S3 — Search and sort · READY_FOR_REVIEW (2026-11-13)

- **Branch:** `feature/search-sort` (from `develop` at `59415a9`). **Head:** the `docs: record S3 review gate` commit on top of `d914611`.
- **Scope confirmed by the developer** (2026-11-13): as planned, with the agent's recommendation on all four open choices: toolbar `Menu` and `sort_options_opened` removed (D-44), skeleton during a sort reload (D-45), sort per list (D-46), browse grid kept alive under search results with an inline title (D-47). Agent decisions D-48 (search triggers and refresh events), D-49 (query metrics, `had_results`), D-50 (what shows during the debounce), D-51 (`+` sent as `%2B`), D-52 (task handles per list). Task plan: [plans/S3-search-sort.md](plans/S3-search-sort.md) (with deviations).
- **Commits:** `0798d8c` S2 completed / S3 in progress · `1d7e230` task plan + D-44–D-52 · `d62fa52` `ProductsTarget.search` + `%2B` · `ef6d78d` repository search · `7cc7d1e` `SearchQuery` · `3ef52cb` `TestClock` sleeping · `c76d907` search and sort analytics events (5 → Active, `sort_options_opened` removed) · `4f603bf` refactor: list state per feed · `ecdd8fa` debounced search · `5c52a6d` server-side sort · `d914611` search field and sort menu · review-gate docs.
- **Changed files:**
  - App: `Shared/Products/Data/{ProductsTarget, LiveProductRepository}.swift`, `Shared/Products/Domain/ProductRepository.swift`, `Networking/URLSessionAPIClient.swift` (`%2B`), `Core/Analytics/AnalyticsEvent.swift`, `Features/Catalog/Domain/SearchQuery.swift` (new), `Features/Catalog/Presentation/{CatalogFeed (new), ProductSort+Title (new), CatalogViewModel, CatalogPhase, CatalogView}.swift`.
  - Tests: new `Features/Catalog/{CatalogViewModelSearchTests, CatalogViewModelSortTests, SearchQueryTests, ProductSortTitleTests}`, `Core/Analytics/SearchAnalyticsEventTests`, `Support/TestClockTests`; additions to `ProductsTargetTests`, `URLSessionAPIClientTests`, `LiveProductRepositoryTests`; `CatalogViewModelTests` call sites (`itemAppeared(id:in:)`); `TestClock` (deterministic `sleep`, `waitForSleepers`), `FakeProductRepository` (query, `search`, `resumeNewest`).
  - Docs: Analytics.md (5 events Active, `sort_options_opened` removed with the reason, D-45/D-48/D-49 notes), ProductSpecification § 4.1 states table and § 4.2, Networking.md A13 and § 2, Architecture § 2/5/8, README status, AILog, this file, the task plan.
- **Build settings** (`xcodebuild -showBuildSettings`, 2026-11-13): unchanged (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation). No packages.
- **Build:** `xcodebuild … clean build` (Debug, iPhone 17, iOS 26.0 Simulator): `** BUILD SUCCEEDED **`; result bundle **0 warnings**, 0 errors, 0 analyzer warnings (the raw log again has only the `appintentsmetadataprocessor` "Metadata extraction skipped" tool line). `xcodebuild … -configuration Release build`: succeeded; result bundle 0 warnings, 0 errors.
- **Tests:** `xcodebuild … test`: **200 passed, 0 failed, 0 skipped** in 33 suites (result bundle summary). New suites: `CatalogViewModelSearchTests` 23, `CatalogViewModelSortTests` 9, `SearchQueryTests` 3, `TestClockTests` 4, `ProductSortTitleTests` 2, `SearchAnalyticsEventTests` 1 (9 cases); `ProductsTargetTests` grew from 2 to 4, `URLSessionAPIClientTests` from 10 to 12, `LiveProductRepositoryTests` from 2 to 3. Counts are test functions; parameterized ones run more cases.
- **Red first:** every new suite failed on compilation first (missing types or members); `searchQueryIsPercentEncoded` also failed on its assertion before the `%2B` fix. Tests that passed when first run, because earlier S3 code already handled them (search pagination, refresh and teardown; the hidden-list guard), were mutation-checked: with the guarded line removed each failed. Details in the task plan's deviations.
- **Manual Simulator checks for the developer** (the agent did not run the app):
  1. Run the Debug build on an iOS 26 iPhone simulator. The Catalog tab has an inline "Catalog" title, the "Search products" field always visible under it, a sort control at the top left reading "Default" with an up-down arrow icon, and the Diagnostics button at the top right. The grid loads as in S2.
  2. Fast typing (plan check 1): Diagnostics → Network → turn on "Slow network". Type "phone" quickly: the browse grid stays while typing; about 300 ms after the last key the skeleton appears. Console `network` shows exactly **one** search request, `GET https://dummyjson.com/products/search?q=<private>&limit=20&skip=0&delay=2000`. Then 20 results. Events: `search_started` (`sort: default_order`), `search_performed` (`trigger: typing`, `query_length: 5`, `word_count: 1`, `result_count: 20`, `total_count: 23`).
  3. Stale responses (slow network on): type "pho", wait about 0.5 s (the request starts), then type "ne". The first request ends as cancelled in Console `network`, only "phone" results appear, and there is one `search_performed`, for the 5-character query.
  4. Search "phone" with each sort (plan check 2): pick "Price: Low to High" in the sort menu: skeleton, then results in ascending price; the label reads "Lowest price". Scroll to the end: 23 results, still ascending across the page boundary, then "You've reached the end". Events: `sort_changed` (`from_sort: default_order`, `to_sort: price_asc`, `list_context: search`), `search_performed` (`trigger: sort_change`), `catalog_page_requested`/`catalog_page_loaded` with `list_context: search`. Repeat with "Price: High to Low" and "Rating: High to Low". Re-selecting the current option does nothing.
  5. Clear (AC-S4): first scroll browse well down (40+ products loaded, a recognizable product at the top). Search "phone", change the sort, then clear with the field's clear button or Cancel. The browse grid is back **instantly at the same scroll position** with its thumbnails, the label reads "Default" again, and Console shows no request. Event: `search_cleared` (`query_length: 5`, `had_results: true`).
  6. No results (AC-S5): search "zzzz": "No results", `No products match "zzzz"` (straight quotes) and Clear search. Tapping Clear search returns to browse and dismisses the search field and keyboard. Events: `search_performed` (`total_count: 0`), `search_cleared` (`had_results: false`).
  7. Browse sort: in browse, pick "Rating: High to Low": skeleton, then the highest-rated products first, scrolled to the top. Event `catalog_load_completed` (`trigger: sort_change`, `sort: rating_desc`).
  8. Search failure: network off, search "phone": full-screen "Couldn't search products" with the offline message and Retry; `search_failed` (`trigger: typing`, `query_length: 5`, `error_type: offline`). Network on, Retry: results; `retry_requested` (`failed_surface: search`), then `search_performed` (`trigger: retry`).
  9. Pull to refresh while results are shown: content stays; `catalog_refreshed` (`list_context: search`), no `search_performed`.
  10. `+` encoding (A13, D-51): "iphone charger" finds 1 product (Apple iPhone Charger); "iphone+charger" shows no results, because the `+` is sent literally.
  11. Tabs: with results shown, switch to Saved and back: one `catalog_viewed` with `list_context: search`; results, search text and sort are kept.
  12. Optional: VoiceOver reads the sort control as "Sort, Default"; browse cards can't be reached while results are shown. Dark mode and an iPad simulator.
  13. ⌘U in Xcode: 200 tests pass.
- **Known limitations:**
  - The two-layer layout (exact scroll restore, inline title, the hidden layer inert to taps and VoiceOver) is expected SwiftUI behavior, checked manually (checks 1, 5, 12), not by unit tests.
  - While results are shown, the browse cells that were on screen keep their thumbnails in memory (D-47). If browse page 1 finishes loading in the background while hidden, its first cells' thumbnails load although hidden (expected, not verified).
  - A sort change while browse page 1 is still loading from `.task` can briefly leave two page-1 requests in flight: the structured load can't be cancelled from the view model, and its result is dropped by generation.
  - A pull-to-refresh pauses load-more of both lists until it ends (one refresh flag).
  - A sort change during the debounce of a first search applies to browse (still on screen); the search then starts in that sort.
  - If an in-flight search is cancelled because the user types a new query, the skeleton stays until the new query starts (at most the 300 ms debounce).
  - Opening the sort menu is not measured (D-44).
- **Open questions:**
  1. (From S2.) D-43 maps only `notConnectedToInternet`, `networkConnectionLost` and `dataNotAllowed` to "offline". Should other codes seen with the network off also count?
  2. The toolbar label uses short names ("Default", "Lowest price", "Highest price", "Top rated"); the spec fixes only the menu titles. Are these OK?
  3. The sort control sits at the toolbar's leading edge, so its label stays clear of the centered inline title and the DEBUG Diagnostics button. OK, or should it move to the trailing side?
- **Findings and resolution:** awaiting the developer's Codex review.

#### S3 Codex review — findings and resolution (2026-11-13)

The developer ran an independent Codex review and shared four findings. Each was checked against the code and accepted; each fix went in test-first on this branch, as its own commit.

| # | Finding | Assessment | Fix | Tests |
|---|---|---|---|---|
| 1 | P1 — Cancel on the search field must clear the query, return to browse, cancel in-flight search work and send exactly one `search_cleared` | Accepted. The view relied on the system emptying the text binding on Cancel; nothing ended the search when the field was dismissed. | `ad651e3`: the view reports `isPresented` going from true to false as `searchDismissed()`, which clears the query like an empty text. If the system also empties the text, before or after, that change is a no-op. | `cancelEndsTheSearchOnce` (3 cases: dismissal only, then empty text, empty text first): failed on compilation first; the dismissal-only case was mutation-checked (with an empty `searchDismissed()` it failed with 5 issues). The view's `onChange` wiring is checked manually (check 14). |
| 2 | P1 — every sort change must reload page 1 and show the list from the top, explicitly, in browse and search | Accepted. A new grid started at the top only because the skeleton replaced it for at least one frame; if both state changes were applied in one update, the old grid and its offset would stay. | `9ebaac0`: each page-1 load (sort change, new query, Retry, Reload) gives the list a new `listID`, and the view keys the grid by it (`.id(listID)`). A view with a new identity is a new view with fresh state, so its scroll view starts at the top, whether or not the skeleton frame was drawn. Load-more and refresh keep the `listID`, so the grid, its scroll position and the refresh control stay. | `sortChangeStartsANewBrowseList`, `sortChangeStartsANewSearchList`, `loadMoreAndRefreshKeepTheList`: compile failure first; the last was mutation-checked (with refresh also changing `listID` it failed). The scroll itself is checked manually (check 15). |
| 3 | P2 — no-results copy must be exactly `No products match "<query>"` with straight quotes | Accepted. The view used typographic quotes. | `a48347c`: `CatalogCopy.noResultsMessage(for:)` holds the text; the view uses it. | `noResultsMessageMatchesTheSpec`: compile failure first, then pass. |
| 4 | P2 — `ProductSort` should be `Identifiable` with a stable `id`, as planned | Accepted. The plan's Task 8 interface listed it; the menu used `id: \.self` instead. | `bf86ee2`: `extension ProductSort: Identifiable { var id: Self { self } }`; the menu's `ForEach` uses it. | `idIsTheSortItself`: compile failure first, then pass. |

- **Re-verification:** `xcodebuild … clean build`: result bundle **0 warnings**, 0 errors, 0 analyzer warnings; Release build 0 warnings, 0 errors; `xcodebuild … test`: **206 passed, 0 failed, 0 skipped** in 34 suites (200 + 6 new test functions; new suite `CatalogCopyTests`).
- **Added manual checks** (numbering continues the list above):
  14. Cancel: search "phone" (results shown, or with slow network on while the request is in flight), tap the field's **Cancel**: browse is back instantly at its scroll position, the keyboard and Cancel button are gone, the field is empty, and Diagnostics shows exactly **one** `search_cleared`; Console `network` shows the in-flight request cancelled, if there was one. Also: with results shown, switch to Saved and back: the search stays (the field isn't dismissed by a tab switch; expected, please confirm).
  15. Sort scroll: in browse, scroll well down, then pick another sort: the new order starts at the top. The same while searching (scroll the results to the end, change the sort).
- **Known limitation added:** if the system ever dismissed the search field without the user's Cancel (e.g. on a tab switch or, in S4, a push to details), the search would be cleared. Not expected; check 14 covers the tab switch.
- **Scope:** no change beyond the four findings. ProductSpecification § 4.2 now names Cancel; Architecture § 8 describes `listID`.

#### S3 review result (2026-11-13)

- Codex re-review of the four fixes, run manually by the developer: **approved**. Developer's final approval: **approved**. No manual-check results were shared with the agent; open questions 1–3 of the S3 review log (D-43 offline codes, the short sort labels, the sort control at the leading edge) stay open, and the S3 behavior they describe stays as built.
- Status → `APPROVED`. The developer merges `feature/search-sort` into `develop` with `--no-ff`; the next stage's conversation records S3 `COMPLETED` once it confirms the merge.

#### S3 merge (recorded by the S4 conversation, 2026-11-13)

- The developer merged `feature/search-sort` into `develop` with `--no-ff`: merge commit `152da21` (`git branch --merged develop` lists the branch). S3 → `COMPLETED`. S4 (authorized 2026-11-13) starts from `develop` at `152da21` on `feature/product-details`.

### S4 — Product details · READY_FOR_REVIEW (2026-11-13)

- **Branch:** `feature/product-details` (from `develop` at `152da21`). **Head:** the `docs: record S4 review gate` commit on top of `34ffb7c`.
- **Scope confirmed by the developer** (2026-11-13): as planned, with the agent's recommendation on all four open choices: the Catalog tab's `Router` injected into `CatalogViewModel` (D-53), the search guarded against a dismissal while details are pushed (D-54), a rating chip without the review count (D-55), no `is_saved` until S5 (D-56). Agent decisions D-57 (route carries the list's product; no fetch, details Retry or `FailedSurface.details` until S5), D-58 (numbers as given, no units), D-59 (when the details events fire). Task plan: [plans/S4-product-details.md](plans/S4-product-details.md) (with deviations).
- **Commits:** `7e821cb` S3 completed / S4 in progress · `3a79b27` task plan + D-53–D-59 · `9c9e80b` product details fields (+ Networking.md A14) · `ef15a4f` `ProductInsights` · `ad48055` details presentation models · `fa84b05` details analytics events (3 → Active) · `8f5edf8` route, router and details view model · `934c8b8` card selection from the catalog · `34ffb7c` details screen · review-gate docs.
- **Changed files:**
  - App: `Shared/Products/Domain/{Product, ProductInsights (new)}.swift`, `Shared/Products/Data/ProductDTO.swift`, `Core/Navigation/{Route, Router, ProductDetailRoute (new)}.swift`, `Core/Analytics/AnalyticsEvent.swift`, `Features/ProductDetail/Presentation/{ProductDetailView, ProductGalleryView, ProductDetailViewModel, ProductDetailConfigurator, ProductDetailHeader, ProductGalleryModel, ProductFactRow}.swift` (all new), `Features/Catalog/Presentation/{CatalogViewModel, CatalogConfigurator, CatalogView}.swift`, `App/AppTabView.swift`.
  - Tests: new `Shared/Products/ProductInsightsTests`, `Features/ProductDetail/{ProductFactRowTests, ProductDetailHeaderTests, ProductGalleryModelTests, ProductDetailViewModelTests}`, `Features/Catalog/CatalogViewModelSelectionTests`, `Core/Analytics/DetailsAnalyticsEventTests`; additions to `ProductDTOTests`, `RouterTests`, `AppContextRegistrationTests`; `router:` at the three catalog view-model suites' call sites; `ProductCardModelTests` (fixture); `Fakes/ProductFixtures` (`makeProduct` builder).
  - Docs: Analytics.md (3 events Active, `is_saved` from S5, D-59 notes), ProductSpecification § 4.3, Networking.md A14 and § 2, Architecture § 2/6/7, README status, AILog, this file, the task plan.
- **Build settings** (`xcodebuild -showBuildSettings`, 2026-11-13): unchanged (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation). No packages.
- **Build:** `xcodebuild … clean build` (Debug, iPhone 17, iOS 26.0 Simulator): `** BUILD SUCCEEDED **`; result bundle **0 warnings**, 0 errors, 0 analyzer warnings (the raw log again has only the `appintentsmetadataprocessor` "Metadata extraction skipped" tool line). `xcodebuild … -configuration Release build`: succeeded; result bundle 0 warnings, 0 errors. The test action's log has no compiler warnings either (see the task plan's Task 1 deviation).
- **Tests:** `xcodebuild … test`: **240 passed, 0 failed, 0 skipped** in 41 suites (result bundle summary). New suites: `ProductInsightsTests` 6, `ProductFactRowTests` 1 (24 cases), `ProductDetailHeaderTests` 2, `ProductGalleryModelTests` 3, `ProductDetailViewModelTests` 5, `CatalogViewModelSelectionTests` 7, `DetailsAnalyticsEventTests` 1 (7 cases); `ProductDTOTests` grew from 9 to 16, `RouterTests` from 6 to 7, `AppContextRegistrationTests` from 8 to 9. Counts are test functions; parameterized ones run more cases.
- **Red first:** every new suite failed on compilation first (missing types or members); `CatalogViewModelSelectionTests` also failed on its assertions against a stub. Tests that passed when first run were mutation-checked (the details view model's once-guards, the hidden-list guard, the return-from-details state); details in the task plan's deviations.
- **Manual Simulator checks for the developer** (the agent did not run the app). Values below are from the API on 2026-11-13 (A14).
  1. Run the Debug build on an iOS 26 iPhone simulator. Tap the first card, "Essence Mascara Lash Princess" (id 1): details appear at once, with no spinner (AC-D1). One image, **no** page dots. Header: title, "Essence", "Beauty". At a Glance chips: Rating 2.56; Availability "In stock · 99 units"; Minimum order "48 units"; Shipping "Ships in 3-5 business days"; Returns "No return policy"; Warranty "1 week warranty" (no review count, D-55). Pricing: $9.99 and Discount "−10.48%". Overview: description and tags. Product information: SKU BEA-ESS-ESS-001, brand, category, Weight "4", Dimensions "W × H × D", warranty. Shipping & availability, then "Recent reviews" with 3 reviews (stars, comment, name, date; no email anywhere).
  2. Events in Diagnostics (newest first): `product_details_viewed` (`product_id: 1`, `source: catalog`, `category: beauty`, `availability: in_stock`, `has_discount: true`, `image_count: 1`, `content_origin: list`, **no** `is_saved`) after `product_selected` (`product_id: 1`, `source: catalog`, `position: 0`, `sort: default_order`). Console `network` shows **no** request when details open.
  3. Without brand: search "apple" and open "Apple" (id 16): no brand line in the header and no Brand row in Product information. `product_selected` has `source: search` and the search's sort; going back shows the results, the search text and the field still there (AC-C6, D-54). Then tap Cancel: browse returns and one `search_cleared` is sent (Cancel still works after returning).
  4. Six images: open "300 Touring" (id 167; e.g. search "touring", or sort by price high to low): page dots show 6 pages; swipe through them: each image shows a placeholder, then the picture. Exactly **one** `product_gallery_interacted` (`image_count: 6`) for the visit, however many swipes; leave and open it again: a new `product_details_viewed` and, after a swipe, a new gallery event.
  5. Edge data: "Sportbike Motorcycle" (id 117) reads "Out of stock · 0 units" and Stock "0 units"; "Sports Sneakers Off White Red" (id 92) shows Discount "−0.04%".
  6. Back restores state (AC-C6): in browse, scroll well down (60+ products), change the sort, open a product, go back (button and edge swipe): same scroll position, same products and sort, no `catalog_viewed`, no new `catalog_load_completed` and no request in Console. The thumbnails on screen download again (no cache, D-10). Do the same from search results.
  7. Search dismissal on push (D-54 risk): with search results shown and the search field active (keyboard dismissed, Cancel visible), open a product and go back. Please record whether the field is still active. Either way the results must still be there and `search_cleared` must not have been sent.
  8. Tabs: open details, switch to Saved and back: details are still shown and no second `product_details_viewed` is sent; going back to the grid sends no `catalog_viewed` (D-39).
  9. Quick VoiceOver pass on details: the title and section titles are headings; each At a Glance chip reads label and value; each gallery page reads "Product image n of m" (the image component itself is decorative, so please confirm the page element is reachable); review stars read "Rated n of 5". Cards in the grid read as buttons.
  10. Optional: dark mode and an iPad simulator: the chips, rows and page dots stay readable.
  11. ⌘U in Xcode: 240 tests pass.
- **Known limitations:**
  - Rendering, the gallery's paging, page-indicator visibility, per-page image loading in a page-style `TabView`, scroll restoration on back and whether SwiftUI deactivates the search field on a push are expected SwiftUI behavior, checked manually (checks 1, 4, 6, 7, 9), not by unit tests. `product_details_viewed` relies on `onAppear` firing once when the screen is pushed.
  - A page-style `TabView` may create the neighboring page before it is visible, which would start that image's download early (expected, not verified).
  - Returning from details re-downloads the visible thumbnails (no cache, D-10).
  - Details show the product as the list loaded it; there is no refresh from `/products/{id}` and no details Retry until S5 (D-57).
  - Weight and dimensions have no units because the API states none (A14).
  - No save button yet (S5).
- **Open questions:**
  1. (From S2.) D-43: which other `URLError` codes, if any, should count as offline?
  2. (From S3.) The short sort labels and the sort control at the toolbar's leading edge.
  3. Category names are shown as the API's slug in words ("Mens Shirts", "Womens Jewellery"), without an apostrophe or other rewording. OK?
- **Findings and resolution:** awaiting the developer's Codex review.

#### S4 review result (2026-11-13)

- Independent Codex review, run manually by the developer: **no findings**. Developer's final approval: **approved**. No manual-check results were shared with the agent; the S4 open questions (D-43 offline codes, the S3 sort labels and position, category display names) stay open, and the behavior they describe stays as built.
- Status → `APPROVED`. The developer merges `feature/product-details` into `develop` with `--no-ff`; the next stage's conversation records S4 `COMPLETED` once it confirms the merge. S5 is not yet authorized.

#### S4 merge (recorded by the S5 conversation, 2026-11-13)

- The developer merged `feature/product-details` into `develop` with `--no-ff`: merge commit `46b8e6d` (parents `152da21` and `ce63683`; `git branch --merged develop` lists the branch). S4 → `COMPLETED`. S5 (authorized 2026-11-13) starts from `develop` at `46b8e6d` on `feature/saved-products`.

### S5 — Saved products · READY_FOR_REVIEW (2026-11-13)

- **Branch:** `feature/saved-products` (from `develop` at `46b8e6d`). **Head:** the `docs: record S5 review gate` commit on top of `f82bbd3`.
- **Scope confirmed by the developer** (2026-11-13): as planned; agent recommendations accepted for the card save button as a sibling overlay (D-60), `TabSelection` for Browse catalog (D-61), an enum route (D-62) and `product_details_viewed` from Saved at the first appearance with `snapshot` (D-63). The developer chose `saved_product_revisited` inside `AnalyticsService` (D-64) and leaving an unknown-version file in place (D-65) over the agent's recommendations. Agent decisions D-66 (file format, launch load and write order), D-67 (details from Saved), D-68 (property definitions). Task plan: [plans/S5-saved-products.md](plans/S5-saved-products.md) (with deviations).
- **Commits:** `bbab473` S4 completed / S5 in progress · `33c3a3c` task plan + D-60–D-68 · `04b9782` saved snapshot and file repository · `bd342f4` saved products store (+ `saved_products_count`) · `bdcfd3a` detail endpoint (+ Networking.md § 2) · `794972b` saved analytics events (5 → Active) and revisit derivation · `a016921` saved route and tab selection · `050bff2` save from catalog cards · `2234766` details save, snapshot and refresh · `f82bbd3` Saved tab · review-gate docs.
- **Changed files:**
  - App: new `Shared/Saved/{Domain/SavedProduct, Domain/SavedProductsRepository, Data/FileSavedProductsRepository, SavedProductsStore, SavedProductFormat}.swift`, `Core/Navigation/TabSelection.swift`, `Features/Saved/Presentation/{SavedView, SavedViewModel, SavedRowModel, SavedConfigurator}.swift`, `DesignSystem/Components/SaveButton.swift`; moved `App/AppTab.swift` → `Core/Navigation/AppTab.swift`; changed `Core/Analytics/{AnalyticsEvent, AnalyticsValue, AnalyticsService, UserProperty}.swift`, `Core/Navigation/{ProductDetailRoute, Route}.swift`, `Shared/Products/{Domain/ProductRepository, Data/ProductsTarget, Data/LiveProductRepository}.swift`, `Features/Catalog/Presentation/{CatalogViewModel, CatalogConfigurator, CatalogView}.swift`, `Features/ProductDetail/Presentation/{ProductDetailViewModel, ProductDetailConfigurator, ProductDetailView}.swift`, `App/{AppContext, AppTabView, MerchantCatalogApp}.swift`.
  - Tests: new `Shared/Saved/{SavedProductTests, FileSavedProductsRepositoryTests, SavedProductsStoreTests, SavedProductFormatTests}`, `Features/Saved/{SavedRowModelTests, SavedViewModelTests}`, `Features/Catalog/CatalogViewModelSaveTests`, `Features/ProductDetail/ProductDetailSavedTests`, `Core/Analytics/SavedAnalyticsEventTests`, `Core/Navigation/TabSelectionTests`, `Fakes/InMemorySavedRepository` (+ `loadedSavedStore`), `Support/TemporaryDirectory`; additions to `ProductsTargetTests`, `LiveProductRepositoryTests`, `AnalyticsServiceTests`, `AnalyticsEventTests`, `DetailsAnalyticsEventTests`, `RouterTests`, `ProductDetailViewModelTests`, `AppContextRegistrationTests`, `Fakes/FakeProductRepository` (`product(id:)` queue); `savedProducts:` at the other catalog suites' call sites.
  - Docs: Analytics.md (5 events Active, `is_saved`, `content_origin` `list` | `snapshot`, property definitions, `saved_products_count`), ProductSpecification § 4.3/4.4 as built, Architecture § 2/5/6/7/9, Networking.md § 2, README status, AILog, this file, the task plan.
- **Build settings** (`xcodebuild -showBuildSettings`, 2026-11-13): unchanged (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation). No packages.
- **Build:** `xcodebuild … clean build` (Debug, iPhone 17, iOS 26.0 Simulator): `** BUILD SUCCEEDED **`; result bundle **0 warnings**, 0 errors, 0 analyzer warnings. `xcodebuild … -configuration Release build`: succeeded; result bundle 0 warnings, 0 errors. The test action's log has no compiler warnings (only the `appintentsmetadataprocessor` "Metadata extraction skipped" tool line).
- **Tests:** `xcodebuild … test`: **312 passed, 0 failed, 0 skipped** in 51 suites (result bundle summary). New suites: `SavedProductTests` 2, `FileSavedProductsRepositoryTests` 8, `SavedProductsStoreTests` 11, `SavedProductFormatTests` 2, `SavedAnalyticsEventTests` 3 (one parameterized with 11 cases), `TabSelectionTests` 2, `CatalogViewModelSaveTests` 6, `ProductDetailSavedTests` 14, `SavedRowModelTests` 1, `SavedViewModelTests` 8. Grown: `ProductsTargetTests` 4 → 5, `LiveProductRepositoryTests` 3 → 5, `AnalyticsServiceTests` 9 → 14, `RouterTests` 7 → 8, `ProductDetailViewModelTests` 5 → 9, `AppContextRegistrationTests` 9 → 11. Counts are test functions.
- **Red first:** every new suite failed on compilation first; the event test also failed on a real value (the `price` double drift, fixed). Tests that passed when first run were mutation-checked (store write chain and merge, revisit dedup and per-session reset, the catalog's hidden-list guard, the details view model's deinit cancel and 404 branch); details in the task plan's deviations.
- **Manual Simulator checks for the developer** (the agent did not run the app). Events are in Diagnostics (newest first).
  1. **Save from a card:** on the Catalog grid, tap the bookmark on "Essence Mascara Lash Princess" (id 1; top-right of the thumbnail). The icon fills, the card does **not** open, the Saved tab shows badge **1**. Event `product_saved` (`product_id: 1`, `surface: catalog_card`, `category: beauty`, `price: 9.99`, `position: 0`, `saved_count_after: 1`); user property `saved_products_count` 0 → 1. Tapping the card itself still opens details.
  2. **All surfaces (AC-V1, AC-D3):** open id 1's details: the toolbar bookmark is filled. Tap it: it empties, `product_unsaved` (`surface: details`, `saved_duration_s`, `saved_count_after: 0`); go back: the card icon is empty, the badge is gone. Save it again from the toolbar (`product_saved`, `surface: details`, no `position`). From search results ("phone"), save a result: `surface: search_card` with its position.
  3. **Saved tab:** switch to Saved: `saved_products_viewed` (`saved_count`). Rows newest first, each with thumbnail, title, "Price when saved: $9.99" and "Saved <day> <month>" in your locale, no rating. Switch away and back: one more `saved_products_viewed` per switch; popping back from details sends none. Please record whether every switch sends one (it relies on the hidden tab's view receiving the tab change, like `catalog_viewed`).
  4. **Details from Saved:** tap a row: `product_selected` (`source: saved`, `position`, no `sort`), then `product_details_viewed` (`source: saved`, `category`, `is_saved: true`, `content_origin: snapshot`, no `availability`/`has_discount`/`image_count`). The snapshot shows first ("Saved information · Saved …", title, category, rating, price, no gallery), "Updating…" briefly (turn on DEBUG slow network to see it), then the full details with the gallery. Console `network`: one `GET /products/1`.
  5. **Revisit:** save a product, wait 30+ minutes with the app in the background (or relaunch the app: a cold launch starts a new session), then open it from Saved or the catalog: `saved_product_revisited` (`days_since_saved: 0`) right after `product_details_viewed`; opening it again in the same session sends none.
  6. **Terminate and relaunch (AC-V2):** with 2–3 saved products, stop the app in Xcode and run again: the same items, same order, the badge count, card icons filled; `saved_products_count` is set once at launch.
  7. **Offline (AC-V3, AC-D4):** turn the Mac's network off. The Saved tab still lists every row (thumbnails show the placeholder icon). Open a row: the snapshot plus "Couldn't refresh — showing saved info" and **Retry**; event `product_details_load_failed` (`error_type: offline`, `showing_snapshot: true`). Turn the network on, tap Retry: `retry_requested` (`failed_surface: details`), then the full details.
  8. **Swipe to remove (AC-V4):** swipe a row left: it disappears, `product_unsaved` (`surface: saved_list`); back on Catalog the card's icon is empty. Remove all: the empty state with **Browse catalog**, which switches to the Catalog tab.
  9. **No longer available / price changed** (not reachable with live data: every saved id exists and prices don't change). Optional, by editing the saved file: `xcrun simctl get_app_container booted com.example.MerchantCatalog data`, then edit `Library/Application Support/saved-products.json` with the app stopped: set an item's `"id"` to `99999` → its details show the snapshot with "This product is no longer available." and no Retry (`error_type: not_found`); or change an item's `"price"` to `"1.00"` → after the refresh, Pricing shows "Price changed since you saved it" and "Price when saved: $1.00".
  10. **Corrupt file:** with the app stopped, replace the file's contents with `not json` and launch: the Saved tab is empty, no crash; the folder holds `saved-products.corrupt-<timestamp>.json`; Console `persistence` has an error line.
  11. VoiceOver on a card (after the review fix): one element, e.g. "Essence Mascara Lash Princess, $9.99, not saved, button"; double-tap opens details; swipe up/down offers the action "Save" ("Remove from Saved" once saved), which toggles the bookmark and the badge without leaving the grid. The save button itself is not a separate VoiceOver stop. Without VoiceOver, the bookmark still takes taps on its own and the card still opens details. Optional: dark mode for the card's bookmark circle.
  12. ⌘U in Xcode: 312 tests pass.
- **Known limitations:**
  - Details from Saved have no gallery until the fresh data arrives, so the layout grows when it does (D-67).
  - `saved_products_viewed` relies on the Saved view receiving the tab change while hidden, as `catalog_viewed` does (D-39); checked manually (check 3).
  - A saved-products file with an unknown version is overwritten by the next save (D-65, the developer's choice).
  - A failed write is only logged; the in-memory list stays and the next change writes again.
  - `days_since_saved` counts 24-hour periods, not calendar days (D-68).
  - Rendering, swipe actions, the badge, the toolbar button and the card overlay's hit areas are SwiftUI behavior checked manually, not by unit tests.
- **Open questions:**
  1. (From S2.) D-43: which other `URLError` codes, if any, should count as offline?
  2. (From S3.) The short sort labels and the sort control at the toolbar's leading edge.
  3. (From S4.) Category names shown as the slug in words ("Mens Shirts").
  4. Details from Saved price the snapshot under "Price" with the "Saved information · Saved …" note above; would you rather label that row "Price when saved" until the refresh?
- **Findings and resolution:** awaiting the developer's Codex review.

#### S5 Codex review — findings and resolution (2026-11-13)

The developer ran the independent Codex review and asked for all three fixes on the branch. Each was checked against the code, confirmed and fixed test-first.

1. **A cancelled Saved-details refresh could still apply its response.** `start()` and the Retry task applied whatever the repository returned; if the response arrived before the cancellation reached the request (the fake answers with success after `cancel()`), the fresh product replaced the snapshot after the user had left. Both now treat a result from a cancelled task as `CancellationError` (existing path: back to `idle`, snapshot kept, no event). Tests `cancellationWinsOverALateSuccess` and `cancelledRetryIgnoresALateSuccess` failed first (state `refreshed`, fresh product applied). Commit `0ba9adb`.
2. **The saved repository wasn't registered by its protocol** (Architecture § 4). `AppContext` now builds one `FileSavedProductsRepository`, registers it as `any SavedProductsRepository` and injects that instance into `SavedProductsStore`. `savedRepositoryIsRegisteredByProtocol` failed first; a first fix still failed because passing an `any` value to the generic `register<T>` opens the existential and registers the concrete type, so the call uses `as any SavedProductsRepository` like the other registrations (commented). `savedStoreUsesTheRegisteredRepository` writes through the resolved repository (temporary directory) and loads it through the store. Commit `c90bae6`.
3. **Catalog cards weren't one VoiceOver element** (ProductSpecification § 4.5). The card and its save button now form one element: label "Title, price[, rated n of 5], saved/not saved" (`ProductCardAccessibility`; the rating is `nil` until S6's treatment arm), the button trait and default action open details, and a custom action "Save" / "Remove from Saved" toggles the store. The visible bookmark stays a separate 44 pt touch target, not nested in the card's button. `ProductCardAccessibilityTests` (3) failed first on compilation. The action name comes from `SaveButton.title(isSaved:)` (`nonisolated`, so the composer can call it outside the main actor). This takes the card part of S7's accessibility pass forward (D-60 updated). Commit `be7c92b`.

- **Re-verification** (2026-11-13): `git diff --check` clean (working tree and `46b8e6d..HEAD`). `xcodebuild … clean build` (Debug): succeeded, result bundle 0 warnings / 0 errors / 0 analyzer warnings. Release build: succeeded, 0 warnings / 0 errors. `xcodebuild … test`: **319 passed, 0 failed, 0 skipped** in 52 suites (+7: `ProductDetailSavedTests` 14 → 16, `AppContextRegistrationTests` 11 → 13, new `ProductCardAccessibilityTests` 3); the test log has no compiler warnings.
- **Remaining limitations:** VoiceOver's element and actions are SwiftUI behavior checked manually (check 11), not by unit tests; with the card as one element, Voice Control can't name the bookmark separately ("Tap Save"), only the card. The rating part of the label is tested but unused until S6.

#### S5 review result (2026-11-13)

- Codex re-review of the three fixes, run manually by the developer: **no findings**. Developer's final approval: **approved**. No manual-check results were shared with the agent; the S5 open questions (D-43 offline codes, the S3 sort labels and position, category display names, a "Price when saved" label on the snapshot's price row) stay open, and the behavior they describe stays as built.
- Status → `APPROVED`. The developer merges `feature/saved-products` into `develop` with `--no-ff`; the next stage's conversation records S5 `COMPLETED` once it confirms the merge. S6 is not yet authorized.

#### S5 merge (recorded by the S6 conversation, 2026-11-13)

- The developer merged `feature/saved-products` into `develop` with `--no-ff`: merge commit `dc04338` (parents `46b8e6d` and `e2d4f0c`; `git branch --merged develop` lists the branch). S5 → `COMPLETED`. S6 (authorized 2026-11-13) starts from `develop` at `dc04338` on `feature/card-rating-experiment`.

### S6 — Card rating experiment · READY_FOR_REVIEW (2026-11-13)

- **Branch:** `feature/card-rating-experiment` (from `develop` at `dc04338`). **Head:** the `docs: record S6 review gate` commit on top of `5afca46`.
- **Scope confirmed by the developer** (2026-11-13): as planned; agent recommendations accepted for the assignment resolved once per launch with the override and reset applied at the next launch (D-69), a `CardExperiment` value injected into `CatalogViewModel` with exposure from `itemAppeared` (D-70), "★ 4.9" with one fraction digit and a hidden placeholder row in control (D-71), and the reset keeping the override (D-72). Agent decisions D-73 (uppercase id, big-endian bytes, launch resolution, unknown stored value re-bucketed) and D-74 (session id read after tracking; a resumed session is exposed at the next card appearance). Task plan: [plans/S6-card-rating-experiment.md](plans/S6-card-rating-experiment.md) (with deviations).
- **Commits:** `f3fd9ab` S5 completed / S6 in progress · `53d6e65` task plan + D-69–D-74 · `05963ff` bucketing · `3f10810` experiment service + `experiment_assignments` (Analytics.md § 2) · `e520d59` exposure tracker, `experiment_exposed` → Active · `9fc8d11` rating on treatment cards + exposure from the grid · `5afca46` Diagnostics override · review-gate docs.
- **Changed files:**
  - App: new `Core/Experiments/{Experiment, ExperimentAssigner, ExperimentService, LocalExperimentService, ExposureTracker}.swift`, `Features/Catalog/Presentation/CardExperiment.swift`; changed `Core/Analytics/{AnalyticsEvent, AnalyticsValue, UserProperty}.swift`, `App/AppContext.swift`, `Features/Catalog/Presentation/{ProductCardModel, ProductCardView, CatalogFeed, CatalogViewModel, CatalogConfigurator, CatalogView}.swift`, `Features/Diagnostics/Presentation/{DiagnosticsViewModel, DiagnosticsConfigurator, DiagnosticsView}.swift`.
  - Tests: new `Core/Experiments/{ExperimentAssignerTests, LocalExperimentServiceTests, ExposureTrackerTests}`, `Features/Catalog/CatalogViewModelExperimentTests`, `Support/CardExperiments`; additions to `AnalyticsEventTests`, `AppContextRegistrationTests`, `ProductCardModelTests`, `DiagnosticsViewModelTests`, `TaxonomyDocumentationTests` (no Planned event left); `cardExperiment:` at the other catalog view-model call sites.
  - Docs: Experiments.md (byte order, id form, per-launch resolution, reset and override timing, exposure definition), Analytics.md (`experiment_exposed` Active, `experiment_assignments`, reset wording), ProductSpecification § 4.1 as built, Architecture § 2/4/5/6, README status, this file, the task plan.
- **Build settings** (`xcodebuild -showBuildSettings`, 2026-11-13): unchanged (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation). No packages; CryptoKit is a system framework.
- **Build:** `xcodebuild … clean build` (Debug, iPhone 17, iOS 26.0 Simulator): succeeded; result bundle **0 warnings**, 0 errors, 0 analyzer warnings. `xcodebuild … -configuration Release build`: succeeded; 0 warnings, 0 errors (the override code is compiled out). The test action's log has no compiler warnings. `git diff --check develop..HEAD` clean.
- **Tests:** `xcodebuild … test`: **356 passed, 0 failed, 0 skipped** in 56 suites (result bundle summary; +37 since S5). New suites: `ExperimentAssignerTests` 4 (golden buckets parameterized over 4 ids), `LocalExperimentServiceTests` 8, `ExposureTrackerTests` 6, `CatalogViewModelExperimentTests` 7. Grown: `AnalyticsEventTests` +2, `AppContextRegistrationTests` 13 → 15, `ProductCardModelTests` 3 → 7, `DiagnosticsViewModelTests` 9 → 13. Counts are test functions.
- **Red first:** every new suite failed on compilation first; `TaxonomyDocumentationTests` failed on its "a Planned event must remain" control once `experiment_exposed` became Active (control removed, see the task plan), and `userPropertiesAreSortedRows` caught the Diagnostics service's user property reaching the event log (the test now gives the service its own spy). Tests that passed when first run were mutation-checked: the launch cache and stored reuse, the session id read after tracking, the exposure guard in `itemAppeared`, and the reset clearing assignments.
- **Golden values:** buckets for `uuid(0)`, `uuid(1)`, `uuid(3)` and `E621E1F8-…` were computed independently with Python `hashlib`; 10 000 sequential ids give 4 930 control (49.3 %).
- **Manual Simulator checks for the developer** (the agent did not run the app). Events and user properties are in Diagnostics (newest first).
  1. **Assignment at launch:** open Diagnostics. Section "Experiment" shows "Experiment ID: product_card_density_v1" and "This launch: control (hashed)" or "treatment (hashed)"; user property `experiment_assignments` shows `{product_card_density_v1: <same variant>}`. Relaunch (stop and run in Xcode): same variant.
  2. **Force treatment:** pick Override → Treatment; nothing changes on screen ("Changes apply at the next launch"). Relaunch: "This launch: treatment (override)". The catalog cards show "★ 4.9"-style ratings under the price (e.g. "Essence Mascara Lash Princess" ★ 2.6 for its rating 2.56 — check against the details screen's At a Glance rating, which shows up to 2 digits).
  3. **Exposure, catalog:** with treatment forced, after the relaunch the event log has exactly one `experiment_exposed` (`experiment_id: product_card_density_v1`, `variant: treatment`, `assignment_source: override`, `surface: catalog_grid`) right after the first grid appears, not during the skeleton. Scroll to the end, open details and go back, switch tabs: still one per session. Console `experiment` (debug) shows "suppressed" lines for repeats.
  4. **Force control:** Override → Control, relaunch. Cards show no rating, and the **card height is unchanged** compared with treatment (same number of rows on screen; compare screenshots of the first screen in both arms). One `experiment_exposed` with `variant: control`, `assignment_source: override`.
  5. **Auto:** Override → Auto, relaunch: "This launch: … (hashed)", the hashed variant from check 1; exposure with `assignment_source: hashed`.
  6. **Search surface:** at launch the browse grid renders first, so the launch's exposure is `catalog_grid`. To see `search_grid`, start a new session while the grid is already on screen: background the app for 30+ minutes, return, and **without scrolling** type "phone" in the search field. The first card that appears is a search result: one `experiment_exposed` with `surface: search_grid` (D-70, D-74). Clearing the search shows the browse grid again without a new exposure.
  7. **New session:** background the app for 30+ minutes (or relaunch), come back and scroll a little: one new `experiment_exposed` in the new session (D-74: cards already on screen at the return don't count until a card appears).
  8. **Failed load is not exposure:** with the Mac's network off, launch: the full-screen offline error, no `experiment_exposed`. Turn the network on, Retry: the grid appears, then one exposure.
  9. **Reset installation ID:** with Override = Auto, tap Reset installation ID. The installation id changes, a new `session_started` appears; "This launch" and the cards don't change (D-69). Relaunch: "This launch" shows the new id's hashed variant (it may or may not differ: 50 %); repeat the reset + relaunch until it flips to see the re-bucketing. With an override set, the reset keeps it (D-72).
  10. **VoiceOver (treatment):** a card reads e.g. "Essence Mascara Lash Princess, $9.99, rated 2.6 of 5, not saved, button"; control omits the rating. The rating row itself is not a separate element.
  11. **Release build:** Product → Scheme → Edit Scheme → Run → Release, run: no Diagnostics override exists (compiled out); the variant is the hashed one.
  12. ⌘U in Xcode: 356 tests pass.
- **Known limitations:**
  - An override or reset applies at the next launch (D-69, the developer's choice); in the same launch, events after a reset carry the new installation id with the old launch's variant (DEBUG only).
  - A session that starts while cards are already on screen is exposed at the next card appearance, not at the return (D-74). Analysis uses each installation's first exposure, so this affects only per-session counts.
  - Equal card height, the star's look, dark mode, and VoiceOver reading are SwiftUI behavior checked manually (checks 4, 10), not by unit tests (no snapshot tests).
  - Assignment can't be stopped remotely (Experiments.md § Limitations).
- **Open questions:**
  1. (From S2.) D-43: which other `URLError` codes, if any, should count as offline?
  2. (From S3.) The short sort labels and the sort control at the toolbar's leading edge.
  3. (From S4.) Category names shown as the slug in words ("Mens Shirts").
  4. (From S5.) A "Price when saved" label on the snapshot's price row.
- **Findings and resolution:** awaiting the developer's Codex review.

#### S6 Codex review — findings and resolution (2026-11-13)

The developer shared two remaining findings and asked for both fixes on the branch.

1. **The Diagnostics section header was the experiment id, not "Experiment".** The header is now exactly "Experiment"; `product_card_density_v1` shows inside the section as an "Experiment ID" row; the assignment row, the override picker and the footer are unchanged. No test added: views have no unit tests in this project (no snapshot tests), and the view model, which holds the section's data, is unchanged. Manual check 1 updated.
2. **Stale "★ 4.6" in the variant tables.** Experiments.md (variants table) and ProductSpecification § 4.1 (card table and the "as built" note) now describe treatment as the product's API rating formatted to one decimal, e.g. 4.96 → 5.0 (D-71). No result or metric is claimed.

- **Re-verification** (2026-11-13): `git diff --check` clean. `xcodebuild … clean build` (Debug): succeeded, result bundle 0 warnings / 0 errors / 0 analyzer warnings. Release build: succeeded, 0 warnings / 0 errors. `xcodebuild … test`: **356 passed, 0 failed, 0 skipped** in 56 suites; the test log has no compiler warnings.
- Status stays `READY_FOR_REVIEW`, awaiting the developer's re-review.

#### S6 review result (2026-11-13)

- Developer's final approval after the two review fixes (`7ecdeee`, `bbb9123`): **approved**. No manual-check results were shared with the agent; the carried-over open questions (D-43 offline codes, S3 sort labels and position, category display names, a "Price when saved" label) stay open, and the behavior they describe stays as built.
- Status → `APPROVED`. The developer merges `feature/card-rating-experiment` into `develop` with `--no-ff`; the S7 conversation records S6 `COMPLETED` once it confirms the merge.

#### S6 merge (recorded by the S7 conversation, 2026-11-13)

- The developer merged `feature/card-rating-experiment` into `develop` with `--no-ff`: merge commit `efc5c89` (parents `dc04338` and `a4f670b`; `git branch --merged develop` lists the branch). S6 → `COMPLETED`. S7 (authorized 2026-11-13, "merged, start S7") starts from `develop` at `efc5c89` on `feature/release-readiness`.

### S7 — Release readiness · READY_FOR_REVIEW (2026-11-13)

- **Branch:** `feature/release-readiness` (from `develop` at `efc5c89`). **Head:** the `docs: record S7 review gate` commit on top of `838283a`.
- **Scope confirmed by the developer** (2026-11-13): agent recommendations accepted for one grid column at every accessibility size (D-75), card-label tests over all combinations plus the 44 pt fixes with dark mode audited only, a README "Release status" table, and closing the four carried-over open questions as built (D-77). Agent decision D-76 (how the 44 pt targets are sized). Task plan: [plans/S7-release-readiness.md](plans/S7-release-readiness.md) (with deviations).
- **Commits:** `5ebbeae` S6 completed / S7 in progress · `32e367c` task plan · `a1c0c94` card label combinations · `8fb1119` one grid column at accessibility sizes (+ D-75) · `f8f523f` 44 pt buttons (+ D-76) · `d337dce` final taxonomy test + Analytics.md header · `838283a` README, Architecture, ProductSpecification § 4.5, AILog, D-77 · review-gate docs.
- **Changed files:**
  - App: new `Features/Catalog/Presentation/CatalogLayout.swift`; changed `Features/Catalog/Presentation/CatalogView.swift` (layout moved out, Dynamic Type columns, large buttons), `Features/Saved/Presentation/SavedView.swift`, `Features/ProductDetail/Presentation/ProductDetailView.swift`, `DesignSystem/Components/ErrorBanner.swift`.
  - Tests: new `Features/Catalog/CatalogLayoutTests` (3); `ProductCardAccessibilityTests` (3: one parameterized over 4 combinations, a locale test, the action name); `TaxonomyDocumentationTests` 3 → 5.
  - Docs: README (final, Release status, Documentation Index with `docs/plans/`), Architecture (§ 2 tree as built, § 7 route, § 11), ProductSpecification § 4.5 as built, Analytics.md header, AILog (S6 and S7 entries), this file, the task plan.
- **Build settings** (`xcodebuild -showBuildSettings`, 2026-11-13): unchanged (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation). No packages.
- **Build:** `xcodebuild … clean build` (Debug, iPhone 17, iOS 26.0 Simulator): succeeded; result bundle **0 warnings**, 0 errors, 0 analyzer warnings. `xcodebuild … -configuration Release build`: succeeded; 0 warnings, 0 errors. The test action's log has no compiler warnings (only the `appintentsmetadataprocessor` "Metadata extraction skipped" tool line). `git diff --check develop..HEAD` clean.
- **Tests:** `xcodebuild … test`: **361 passed, 0 failed, 0 skipped** in 57 suites (result bundle summary; +5 since S6). New suite `CatalogLayoutTests` 3; `TaxonomyDocumentationTests` 3 → 5; `ProductCardAccessibilityTests` stays 3 (two single cases became one parameterized test, plus a locale test). Counts are test functions.
- **Red first / mutation checks:** `CatalogLayoutTests` failed on compilation first. The label and taxonomy tests lock existing behavior, so they passed at once and were mutation-checked (details in the task plan's deviations). The 44 pt changes are view code without unit tests.
- **Release criteria** (MasterSpecification § 1): assessed in README § Release status. Not met: the current stable Xcode (D-1). Pending the developer: the Simulator smoke checklist below. Image cancellation (D-78): request-level cancellation is verified by `URLSessionImageLoaderTests.cancellationStopsTheRequest` and `ProductImageModelTests`; the only remaining manual expectation is that SwiftUI cancels a cell's `.task` when the cell disappears during scrolling (check 17).
- **Manual Simulator checks for the developer — 1.0 smoke checklist** (the agent did not run the app). Events and user properties are in Diagnostics (newest first).
  1. **Launch and browse (AC-C1):** skeleton, then a 2-column grid of 20 products; `session_started`, `catalog_viewed`, `catalog_load_completed`, one `experiment_exposed`.
  2. **Paginate (AC-C2):** scroll to the end: spinner footer per page, 194 products, no duplicates, "You've reached the end", no further `catalog_page_requested`.
  3. **Refresh (AC-C5):** pull to refresh: the grid never blanks; `catalog_refreshed`. With the network off: the content stays and the dismissible banner shows; its close button takes taps across its whole 44 pt square.
  4. **Offline launch (AC-C3):** Mac network off, launch: full-screen offline error with Retry; network on, Retry: the grid; `retry_requested` then `catalog_load_completed` (`trigger: retry`). Page failure (AC-C4): turn the network off after page 1, scroll: the footer error with Retry; network on, Retry appends the page.
  5. **Search (AC-S1, S2, S5):** with DEBUG slow network on, type "phone" fast: one request in the `network` log; results replace the skeleton; a nonsense query shows "No results" with Clear search; Cancel returns to browse at the same scroll position (AC-S4).
  6. **Sort (AC-S3):** each option in browse and in a search: skeleton, then page 1 in the new order from the top; scroll on: the order continues across pages; the label shows the sort.
  7. **Details (AC-D1, D2, C6):** open products with 1 and several images, with and without brand: no spinner, no empty sections; go back: same scroll position, search and sort.
  8. **Save / unsave (AC-D3, V1, V4):** save from a card's bookmark and from the details toolbar: icons, Saved list and badge update everywhere; swipe to remove in Saved updates the card.
  9. **Relaunch (AC-V2):** stop and run again: the same saved items in the same order, badge and filled icons.
  10. **Saved offline (AC-V3, D4):** network off: the Saved tab lists every row; opening one shows the snapshot plus "Couldn't refresh — showing saved info" and Retry; network on, Retry refreshes.
  11. **Experiment overrides:** Diagnostics → Override Treatment, relaunch: "★ 4.9"-style ratings, `assignment_source: override`; Control, relaunch: no rating, same card height; Auto, relaunch: hashed variant.
  12. **Diagnostics:** event log, user properties (`experiment_assignments`, `saved_products_count`), recent logs, slow-network toggle, reset installation ID (new `session_started`).
  13. **VoiceOver:** a card is one element ("Title, $price[, rated n of 5], saved/not saved, button"); double-tap opens details; the rotor's actions offer "Save" / "Remove from Saved". Buttons on the empty, error and Saved empty states read their titles.
  14. **Largest Dynamic Type (D-75):** Settings → Accessibility → Display & Text Size → Larger Text, largest size (AX5): the catalog and the skeleton show **one column**; titles wrap at two lines; prices and ratings stay readable; the sort menu, search field and buttons stay usable. At the largest non-AX size (xxxLarge) the grid keeps two columns. Check Saved rows and details too.
  15. **44 pt targets (D-76):** with Accessibility Inspector (Xcode → Open Developer Tool), the Retry, Reload, Clear search, Browse catalog and details-banner Retry buttons are at least 44 pt tall; the card bookmark and the refresh banner's close button have a 44 × 44 pt frame.
  16. **Dark mode:** switch the Simulator to dark (Features → Toggle Appearance): every screen (grid, skeleton, cards with ratings, bookmark circle, banners, details, Saved, Diagnostics) is legible with no fixed light backgrounds.
  17. **Image cancellation on scrolling** (D-78): run check 1 of the D-78 change below (Console `network` log, `→ cancelled after … ms` for cells that scrolled away). It checks the one remaining expectation, SwiftUI cancelling the cell's `.task` on disappear; request-level cancellation is already verified by unit tests.
  18. **Release build:** Edit Scheme → Run → Release: the app runs without Diagnostics.
  19. ⌘U in Xcode: 361 tests pass.
- **Known limitations:**
  - Rendering at each text size, hit areas, VoiceOver focus and dark mode are SwiftUI behavior checked manually (checks 13–16), not by unit tests (no snapshot tests).
  - Saved rows keep their horizontal layout at accessibility sizes (out of S7 scope by the developer's choice).
  - The behaviors behind the closed open questions stay as built (D-77): other `URLError` codes count as unknown, short sort labels, slug category names, "Price" on the snapshot row.
  - Image cancellation (D-78): request-level cancellation is verified by `URLSessionImageLoaderTests.cancellationStopsTheRequest` (cancelling the loading task stops the `URLSession` load) and `ProductImageModelTests` (a cancelled load keeps the placeholder and drops late results). The only remaining expectation is SwiftUI's `.task` cancellation when a cell disappears during scrolling (Apple-documented; check 17).
  - Built with Xcode 26.0, not the current 27.2 (D-1).
- **Open questions:** none.
- **Findings and resolution:** awaiting the developer's Codex review.

#### S7 developer change request — image cancellation (2026-11-13)

The developer asked at the gate why image cancellation wasn't working and to implement it: when a cell disappears during fast scrolling while its image is still loading, the load must be cancelled. Assessment: there was no evidence either way. `AsyncImage` offers no API to cancel or observe its request and Apple doesn't document that removing it cancels the download, so the S2 design could only expect it (Networking.md § 4 had the check pending since S2); it also loaded through `URLSession.shared`. The developer accepted the agent's design (D-78; `.task(id:)` trigger and environment injection, over scroll visibility and passing the loader through models).

- **Commits:** `fe0b79f` `ImageLoading` + `URLSessionImageLoader` (own session, no cache, `@concurrent`, `network` log; `URLSessionAPIClient`'s error mapping made internal to share it) · `3c09319` `ProductImageModel`, `ProductImageView` on `.task(id: url)`, `\.imageLoader` environment, registration in `AppContext`, injection in `MerchantCatalogApp` · `e655c6b` docs (Networking § 4, Architecture, ProductSpecification, CLAUDE.md, README, D-78, D-23 superseded, AILog).
- **Tests first:** `URLSessionImageLoaderTests` (4, one parameterized over 5 failures) and `ProductImageModelTests` (8) failed on compilation first; `imageLoaderIsRegisteredByProtocolAndExposed` failed on compilation (`AppContext.imageLoader`). Mutation checks: the request moved into a detached task → `cancellationStopsTheRequest` hit its 1-minute time limit; removing the model's cancellation guards and the initial reset → the late-image, late-failure and new-URL tests failed; registering the loader without `as any ImageLoading` → the registration test failed. `StubURLProtocol` now records `stopLoading` (`waitForStop()`), which proves the `URLSession` load stopped. New fake: `FakeImageLoader` (queued answers: image, failure, until cancelled, held past cancellation).
- **Re-verification** (2026-11-13): `xcodebuild … clean build` (Debug): succeeded, result bundle 0 warnings / 0 errors / 0 analyzer warnings. Release build: 0 warnings / 0 errors. `xcodebuild … test`: **374 passed, 0 failed, 0 skipped** in 59 suites (+13: `URLSessionImageLoaderTests` 4, `ProductImageModelTests` 8, `AppContextRegistrationTests` 15 → 16); the test log has no compiler warnings. `git diff --check` clean.
- **Manual Simulator checks for the developer** (the agent did not run the app):
  1. **Cancellation on fast scroll:** Console.app, filter subsystem `com.example.MerchantCatalog`, category `network`, Action → Include Debug Messages. Turn on macOS Network Link Conditioner "3G" (or "Very Bad Network"). Launch, then fling the catalog grid to the bottom: thumbnail lines of cells that scrolled away read `[<id>] GET https://cdn.dummyjson.com/…/thumbnail.webp → cancelled after … ms`; thumbnails of cells still on screen end with `→ 200 · … ms · … bytes image/webp` (one line per image since the D-80 box format). Scroll back: those thumbnails download again (no cache). Please record the date and result in Networking.md § 4.
  2. **No stale image on reuse:** scroll fast up and down: a cell never shows another product's thumbnail, even briefly; placeholders fill in as images arrive.
  3. **Gallery:** open a product with several images and swipe quickly through the pages: only the pages you stop on load; a page you swiped past mid-load logs `cancelled`.
  4. **Saved tab and details from Saved:** thumbnails and the gallery still load; offline, rows show the placeholder icon (failure) and load when the network returns and the row reappears.
  5. **Failure icon:** with the network off, scroll to new cells: the neutral photo icon; network on, scroll away and back: the image loads.
- **Verified vs expected:** request-level cancellation is verified by `URLSessionImageLoaderTests.cancellationStopsTheRequest` and `ProductImageModelTests` (above). **Remaining expectation:** that SwiftUI cancels `.task` when a cell disappears during scrolling is Apple-documented behavior, not proven by a unit test, and is what manual check 1 confirms; in a lazy grid "disappear" happens when the cell leaves the grid's render window, slightly past the visible edge.
- Status stays `READY_FOR_REVIEW`, awaiting the developer's Codex review of S7 including this change.

#### S7 developer change request — dismiss the search keyboard (2026-11-14)

The developer reported that while searching the keyboard couldn't be put away: scrolling left it up, and the only exit was Cancel, which ends the search. After a short design discussion (approaches and design in [plans/S7-release-readiness.md](plans/S7-release-readiness.md)), the developer chose scroll-to-dismiss plus the Search key (D-79).

- **Commits:** `4729c5e` short design · `264bd4b` `CatalogView`: `@FocusState` bound with `.searchFocused`, `.onSubmit(of: .search)` drops focus, `.scrollDismissesKeyboard(.immediately)` on the grid · docs (D-79, ProductSpecification § 4.2, AILog, this entry).
- **Tests:** none added: the change is three view modifiers with no view-model logic, and the project has no view tests. The existing search tests (debounce, Cancel → `searchDismissed()`) are unchanged.
- **Verification** (2026-11-14): `xcodebuild … clean build` (Debug): succeeded, result bundle 0 warnings / 0 errors / 0 analyzer warnings. A first clean Debug build failed with "cannot open file … .dia for diagnostics emission" for many files in DerivedData (intermediates removed mid-build, most likely by another build of the same project, e.g. Xcode open on it); the rerun succeeded, and no source error was reported. Release build: 0 warnings / 0 errors. `xcodebuild … test`: **374 passed, 0 failed, 0 skipped** in 59 suites; the test log has no compiler warnings. `git diff --check` clean.
- **Manual Simulator checks for the developer** (the agent did not run the app):
  1. **Scroll dismisses:** tap the search field, type "phone", wait for results; start scrolling the results: the keyboard goes away at once; the query stays in the field, the results and the sort label stay, the Cancel button stays.
  2. **Search stays active (the D-79 risk):** after check 1 the results remain on screen and the event log has **no** `search_cleared`. If the search ends instead, dropping focus also deactivates the search on this iOS version; please report it.
  3. **Search key dismisses:** type a query, press the keyboard's Search key: the keyboard goes away, the results stay; no extra `search_performed` beyond the debounced one.
  4. **No results and error states:** type a nonsense query: "No results" shows; Search key dismisses the keyboard; Clear search still works. With the network off, the search error shows; Search key dismisses; Retry works.
  5. **Keyboard back:** tap the field again: the keyboard returns with the query in place; keep typing: the search updates after the debounce.
  6. **Cancel still ends the search:** Cancel clears the field, returns to the browse grid at its scroll position and sends `search_cleared`.
  7. **Browse:** with the field focused and empty, scrolling the browse grid dismisses the keyboard.
- Status stays `READY_FOR_REVIEW`.

##### Follow-up: animated dismissal (2026-11-14)

The developer confirmed the dismissal works but saw no animation, and chose "any scroll, animated" over `.scrollDismissesKeyboard(.interactively)`.

- **Commit:** `CatalogView`: `dismissKeyboard()` drops focus inside `withAnimation` (only when focused); the Search key and `CatalogGrid`'s `.onScrollPhaseChange` (new phase `.interacting`, i.e. a finger drag in either direction) call it; `.scrollDismissesKeyboard(.never)` turns the system's immediate dismissal off so this is the only path. No view-model change, no new test (view behavior).
- **Verification** (2026-11-14): clean Debug build: 0 warnings / 0 errors / 0 analyzer warnings; Release: 0 warnings / 0 errors; `xcodebuild … test`: **374 passed, 0 failed, 0 skipped** in 59 suites, test log free of compiler warnings; `git diff --check` clean.
- **Expected, not verified:** that `withAnimation` around the focus change makes the keyboard slide and the content follow smoothly (the keyboard's slide is UIKit's; `withAnimation` animates SwiftUI's layout change).
- **Manual checks** (in addition to checks 1–7 above): 8. type "phone", then drag the results up **or** down: the keyboard slides away with an animation, the results move with it without a jump; 9. pressing the Search key: the same animated slide; 10. pull-to-refresh with the keyboard up: the keyboard slides away and the refresh still runs; 11. a tap on a card (no drag) with the keyboard up opens details as before.

#### S7 developer change request — extended network logging in DEBUG (2026-11-14)

The developer asked for full network logging: each request with all its fields, headers and parameters, and each response with all its fields. Choices (agent recommendations accepted): DEBUG only, full pretty-printed JSON in chunks, the search term kept `<private>` (D-80). While designing, the agent noticed that product JSON contains `reviews[].reviewerEmail` and added redaction for it.

- **Commit:** `NetworkLogFormatter` (DEBUG only) and `NetworkLogger.responseDetails` (no-op in Release), called by `URLSessionAPIClient` and `URLSessionImageLoader` after the summary line; `started` adds the request details. Docs: Architecture § 2 and § 10, D-80, AILog, this entry.
- **Tests first:** `NetworkLogFormatterTests` (13) failed on compilation first (no `NetworkLogFormatter`); `emailsInJSONBodiesAreRedacted` was added after the rest and failed on a real value (the email in the output) before the redaction existed. Mutation checks: logging `q` in the parameter list, an empty redaction set and a 100× chunk limit each failed the matching tests (search term, credential headers, response headers, chunking).
- **Disk:** the first test run failed with `ld: write() failed, errno=28` (the Mac's data volume had 137 MB free). The developer freed space; the runs below had 13 GB free.
- **Verification** (2026-11-14): `xcodebuild … clean build` (Debug): succeeded, result bundle 0 warnings / 0 errors / 0 analyzer warnings. Release build: 0 warnings / 0 errors; `strings` on the Release binary finds none of the formatter's text, the Debug build's `MerchantCatalog.debug.dylib` does. `xcodebuild … test`: **387 passed, 0 failed, 0 skipped** in 60 suites (+13); the test log has no compiler warnings. `git diff --check` clean.
- **Manual checks for the developer** (Console.app, subsystem `com.example.MerchantCatalog`, category `network`, debug messages included; or Xcode's console):
  1. Launch: the first `GET https://dummyjson.com/products?limit=20&skip=0…` is followed by `[<id>] request GET …`, `query: limit=20, skip=0, …`, `headers: none set by the app (URLSession adds its defaults when sending)`, `timeout: … s`, `body: none`; then `200 in … ms, … bytes`, `response 200, application/json, … bytes`, `headers:` with one indented line per response header, and `body 1/n:` … `body n/n:` chunks of pretty-printed JSON.
  2. Open a product's details from Saved (fetches `/products/{id}`): its body's `reviews` show `"reviewerEmail" : "<redacted>"`.
  3. Search "phone": every line shows `q=<private>`; "phone" appears nowhere in the `network` lines.
  4. Images: thumbnail requests log their headers and `body: … bytes (image/webp), not logged`.
  5. Release build (Edit Scheme → Run → Release): only the summary lines, no `request`/`response`/`body` detail lines.
- Status stays `READY_FOR_REVIEW`.

##### Follow-up: readable log format (2026-11-14)

The developer found the first format unreadable (one message per line, each with `[<id>]`, request and response lines interleaved with other requests, ~25 CDN headers per image) and chose, from three presented layouts, a framed REQUEST box at the start plus a framed RESPONSE box at the end, with image requests as one line each.

- **Measured** (2026-11-14, macOS, a Swift script logging 900–20 000-character messages, read back with `/usr/bin/log show` and `/usr/bin/log stream`): a 900-character message is kept whole; longer ones keep 1,005 payload characters. Boxes are therefore split at line breaks into messages of at most 800 UTF-8 bytes, and every line starts with the frame (`│`), so consecutive messages read as one box. This replaces the earlier "expected, not measured" note.
- **Commit** `8275cee`: `NetworkLogFormatter.requestBox/responseBox/endBox/compactLine`; `NetworkLogger` takes a `Style` (`.detailed` for `URLSessionAPIClient`, `.compact` for `URLSessionImageLoader`); in DEBUG the boxes and image lines replace the one-line summaries; Release keeps the summaries (its failure line now reads `failed after … ms` instead of `failed in … ms`).
- **Tests:** `NetworkLogFormatterTests` rewritten for the boxes (14) and failed on compilation first (no `requestBox`). Mutation checks: no message splitting, no email redaction and logging `q` each failed the matching test.
- **Verification** (2026-11-14): clean Debug build: 0 warnings / 0 errors / 0 analyzer warnings; Release: 0 warnings / 0 errors; the Release binary contains no `REQUEST`/`RESPONSE` box text, the Debug dylib does. `xcodebuild … test`: **388 passed, 0 failed, 0 skipped** in 60 suites; no compiler warnings in the test log. `git diff --check` clean.
- **Manual checks** (replace checks 1 and 4 above; 2, 3 and 5 still apply): 1. launch: a `┌──── → REQUEST [<id>]` box for `/products?limit=20&skip=0`, later a `┌──── ← RESPONSE [<id>] 200 · … ms` box with headers and the pretty-printed body, each closed by `└────…`; a long body continues over several messages with an unbroken `│` frame. 4. scroll the grid: each image is one line `[<id>] GET https://cdn.dummyjson.com/… → 200 · … ms · … bytes image/webp`, or `→ cancelled after … ms` when fast-scrolled away.

#### S7 developer change request — list summaries, details fetched on open (2026-11-14)

The developer asked whether the list could download only what it shows and details load the full product when opened. The agent verified the API's `select` parameter (Networking.md A15) and recommended keeping full list items for 1.0; the developer wanted the change now for the design benefit (most listed products are never opened). Design and plan: [plans/S7-list-summaries.md](plans/S7-list-summaries.md); decisions in D-81.

- **Commits:** `de879a2` design · `7d39542` code + Analytics.md (`ProductSummary`, `ProductSummaryDTO`, `select` on list and search, `ProductPage` of summaries, `SavedProduct` from a summary, `ProductDetailRoute.list(ProductSummary, …)`, details fetch on every route with route-specific status copy, `product_details_viewed` after the fetch for list sources, `content_origin` `network` | `snapshot`) · docs (ProductSpecification § 4.3 and AC-D1, Networking A7/A15, Architecture, README, D-81, D-57/D-63 marked updated, AILog, this entry).
- **Tests first:** the new and rewritten tests failed before the code (`ProductSummaryDTO`/`ProductSummary` missing; `statusMessage` missing; `ContentOrigin.network` missing). Rewritten `ProductDetailViewModelTests` (15, list route): summary first, load, loading state, cancellation, once per screen, failure, 404, Retry, the view event only after the full product, gallery, saving before the load. New `ProductSummaryTests` (2), `ProductDTOTests` +3, `ProductDetailSavedTests` +1 (Saved wording). Updated fixtures (`summary(_:)`, `makeSummary`), the `select` query item in target, repository and client URL tests. Mutation checks: the old Saved-only fetch guard and tracking the view at appearance each failed the list-route tests; dropping `select` failed the target and repository tests.
- **Verification** (2026-11-14): clean Debug build: 0 warnings / 0 errors / 0 analyzer warnings; Release: 0 warnings / 0 errors. `xcodebuild … test`: **400 passed, 0 failed, 0 skipped** in 61 suites (+12); no compiler warnings in the test log. `git diff --check` clean.
- **Manual Simulator checks for the developer:**
  1. **Slim list:** launch with Console's `network` category: the REQUEST box for `/products?limit=20&skip=0&select=title,price,thumbnail,rating,category`; its RESPONSE body lists only `id, title, price, thumbnail, rating, category` per product. Same for a search and after a sort change (`select` before `sortBy`).
  2. **Details from the grid:** tap a card: title, category, rating and price show at once with a gallery skeleton (turn on DEBUG slow network to see it), then the images replace the skeleton and all sections appear; Console shows a `/products/{id}` box. Event log: `product_selected`, then `product_details_viewed` with `content_origin: network`, `availability`, `has_discount`, `image_count`, only after the details appear.
  3. **Leave early:** with slow network on, open a product and go back before it loads: no `product_details_viewed`; the request ends with a `cancelled after … ms` box.
  4. **Offline:** load the grid, turn the Mac's network off, open a product: header + "Couldn't load details" + Retry; `product_details_load_failed` (`showing_snapshot: false`). Network on, Retry: `retry_requested`, then the details and `product_details_viewed`.
  5. **Save from details before the load:** with slow network on, open a product and tap the bookmark at once: it saves (Saved tab shows the row with price and category); `product_saved` has `category`.
  6. **Saved unchanged:** open a saved product: "Saved information · Saved …", "Updating…", then the full details; `product_details_viewed` at the appearance with `content_origin: snapshot`; offline: "Couldn't refresh — showing saved info".
  7. **Back to the grid:** going back still restores the scroll position, search and sort (AC-C6).
- **Known limitation:** details from the catalog or search now need a connection (before D-81 they showed fully from the loaded list); the header still shows offline.
- Status stays `READY_FOR_REVIEW`.

##### Follow-up: gallery skeleton while details load (2026-11-14)

The developer asked for a skeleton in the gallery's place instead of the "Loading details…" line, replaced by the images when they load.

- **Commit** `769f8d9`: `ProductDetailViewModel.showsGallerySkeleton` (while the request hasn't returned: `idle` or `loading`; not after a failure or a 404); `ProductDetailView` shows `GallerySkeleton` (the image placeholder's fill at the gallery's square size, VoiceOver "Loading product images") until the images arrive; details from a list no longer show a loading line (`statusMessage` is `nil` while loading); Saved keeps "Updating…" and also gets the skeleton, so the layout no longer grows when the gallery arrives (the S5 limitation). Agent's calls: the skeleton on both routes, Saved's wording kept.
- **Tests first:** `showsGallerySkeleton` assertions in `ProductDetailViewModelTests` (summary first, while loading, after success, after failure, after 404) and `ProductDetailSavedTests` failed on compilation first. Mutation: a skeleton that stays after a failure failed the failure, 404 and Saved tests.
- **Verification** (2026-11-14): clean Debug build: 0 warnings / 0 errors / 0 analyzer warnings; Release: 0 warnings / 0 errors; `xcodebuild … test`: **400 passed, 0 failed, 0 skipped** in 61 suites (assertions added to existing tests); no compiler warnings in the test log. `git diff --check` clean.
- **Manual checks:** with DEBUG slow network on, open a product from the grid: a grey square skeleton where the gallery goes, no "Loading details…" line, then the images replace it without the content below moving. From Saved: the skeleton plus "Saved information" and "Updating…". Offline: the skeleton disappears and the "Couldn't load details" banner with Retry shows. VoiceOver reads "Loading product images" on the skeleton.

##### Follow-ups: loading skeleton and saved products as summaries (2026-11-14)

The developer asked (1) for the gallery skeleton to show that it is loading, not just a grey box, and (2) for saved products to hold the same data set that goes from the catalog to details, so opening from Saved hands over the same, reusable piece of data.

- **Skeleton** `9f514db`: `GallerySkeleton` now has a large system spinner over the grey square and a slow pulse of the square (0.9 s ease-in-out, repeating); with Reduce Motion the pulse is off and the spinner stays. View-only, no unit test; Debug build 0 warnings.
- **Saved data** `61f3fa2` (D-82): `SavedProduct { summary: ProductSummary; savedAt }`; `ProductDetailRoute.summary` for both routes; `ProductDetailViewModel` starts from `route.summary.displayProduct`; store, row model, analytics and the file repository read `summary`. Tests first: the reshaped `SavedProductTests`, `RouterTests` (`summary` of both routes) and `FileSavedProductsRepositoryTests` (`readsAFileWrittenBeforeTheSummaryShape`, the written keys unchanged) failed on compilation first; every test building a saved product now builds it from a summary. Mutation: a repository that drops `category` on load failed the round-trip and old-file tests.
- **Verification** (2026-11-14): clean Debug build: 0 warnings / 0 errors / 0 analyzer warnings; Release: 0 warnings / 0 errors; `xcodebuild … test`: **401 passed, 0 failed, 0 skipped** in 61 suites (+1); no compiler warnings in the test log. `git diff --check` clean.
- **Manual checks:** (1) with DEBUG slow network on, open a product: the grey square pulses with a spinner in the middle until the images appear; turn on Settings → Accessibility → Motion → Reduce Motion: the spinner stays, the square doesn't pulse. (2) Products saved before this build are still in the Saved tab after updating (same file); saving, opening from Saved and unsaving work as before.

#### S7 final self-check before the review (2026-11-14)

The developer asked for a final review pass before the Codex review. This is the agent's own consistency check, not a review result (the review belongs to the developer and Codex).

- **Branch:** `feature/release-readiness` from `develop` at `efc5c89`; code head `61f3fa2`, docs on top. Nothing merged or pushed.
- **Scope on the branch:** the planned S7 work (D-75–D-77: one grid column at accessibility sizes, 44 pt buttons, final taxonomy test, README and docs) plus the developer's change requests at the gate: D-78 cancellable image loading, D-79 dismissing the search keyboard (animated), D-80 DEBUG network logging in request/response boxes, D-81 list summaries with details fetched on open (+ gallery skeleton), D-82 saved products as summaries.
- **Checks done:** every app source file appears in the Architecture § 2 tree; no stale statement found that list items are full products, that `AsyncImage` is used, or that `content_origin` has a `list` value (historical notes excepted); the diff `develop..HEAD` adds no `@unchecked Sendable`, `nonisolated(unsafe)`, `print`, `try!`, force unwraps, `URLCache` or shared sessions. Fixed in this pass: the stage-status head commit, Networking § 2's S2 note on who requests `/products/{id}`, README's review-trail row (S7's review is still to come) and its limitations (details need a connection) and key-decisions table (list summaries).
- **Results the developer reported** (2026-11-14): the keyboard dismissal works, then its animation works; the extended network log appeared (first format, then replaced by the boxes at the developer's request). No other manual-check results have been shared.
- **Last verification** (2026-11-14, after this docs pass): clean Debug build 0 warnings / 0 errors / 0 analyzer warnings; Release 0 warnings / 0 errors; `xcodebuild … test`: **401 passed, 0 failed, 0 skipped** in 61 suites; no compiler warnings in the test log; `git diff --check develop..HEAD` clean.
- **Open questions for the developer** (behavior stays as built unless changed):
  1. While details load, At a Glance (the rating chip) and Pricing (the price) already show from the summary and then grow when the full product arrives. Keep, or hide every section until the full product is there (only the header and the skeleton)?
  2. Agent's calls open to override: Saved's `product_details_viewed` stays at the first appearance with the snapshot (D-81, so offline revisits count); the details route stays an enum with a shared `summary` (D-82); the large control size for 44 pt buttons (D-76, not measured); the 800-byte log message size (D-80, under the measured ~1 KB cut).
- **Still to check manually** (lists above in this log): the 1.0 smoke checklist; image cancellation on fast scroll (D-78); the boxed network log in Xcode's console and long bodies over several messages (D-80); header-first details, offline details and leaving early (D-81); the pulsing skeleton and Reduce Motion; that saved products from before this build still load (D-82); largest Dynamic Type, 44 pt targets, dark mode, VoiceOver.

#### S7 developer change request — details opened by id, full-screen skeleton (2026-11-14)

Answering the open question from the final self-check (partial sections while details load), the developer called the list data on details noise: details should get just the id, show a skeleton for every part and then the whole product. For Saved the developer chose option A: id-only too, with the snapshot from the store shown when the request fails (offline details from Saved kept). Design: [plans/S7-details-by-id.md](plans/S7-details-by-id.md); decisions in D-83.

- **Commits:** `da519ee` design · `87222b6` code + Analytics.md (`ProductDetailRoute { productID, source }`; `ProductDetailViewModel` with `DetailLoadState`, `DetailScreen`, the snapshot looked up by id, `canToggleSave`, the view event when content first shows; `ProductDetailView` with the redacted, pulsing placeholder layout, a full-screen error, Saved's fallback status; catalog and Saved push the id) · docs (ProductSpecification § 4.3, AC-D1, AC-D4; Architecture § 7; README; D-83 with D-62, D-81, D-82 marked updated; AILog; this entry).
- **Tests first:** the route test and the rewritten `ProductDetailViewModelTests` (19) and `ProductDetailSavedTests` (21) failed on compilation first (no `ProductDetailRoute(productID:source:)`, `screen`, `load`, `canToggleSave`). Mutation checks: no snapshot fallback, no view event on success, a bookmark always enabled, and a cancelled Retry going back to `idle` each failed the matching tests.
- **Verification** (2026-11-14): clean Debug build: 0 warnings / 0 errors / 0 analyzer warnings; Release: 0 warnings / 0 errors; `xcodebuild … test`: **402 passed, 0 failed, 0 skipped** in 61 suites; no compiler warnings in the test log. `git diff --check` clean.
- **Manual Simulator checks for the developer** (DEBUG slow network on makes the skeleton visible):
  1. **From the grid:** tap a card: the whole screen is a skeleton (grey gallery square with a spinner, grey bars for title, chips and sections, pulsing), no title or price from the list; then everything appears at once. The bookmark is dimmed until then. Event log: `product_details_viewed` (`content_origin: network`) only after the content shows.
  2. **Offline from the grid:** full-screen "Couldn't load product" with the offline message and Retry; `product_details_load_failed` (`showing_snapshot: false`); network on, Retry: skeleton, then the product.
  3. **From Saved, online:** the same skeleton, then the product; a changed price shows the note (only reachable by editing the saved file, S5 check 9).
  4. **From Saved, offline:** after the skeleton, the snapshot with "Saved information · Saved …" and "Couldn't refresh — showing saved info" + Retry; events `product_details_load_failed` (`showing_snapshot: true`) then `product_details_viewed` (`content_origin: snapshot`). The bookmark can unsave it.
  5. **Leave early:** go back during the skeleton: no `product_details_viewed`.
  6. **A saved product from the grid:** the bookmark is filled and tappable during the skeleton (removing needs no data).
  7. **VoiceOver:** the skeleton reads "Loading product details"; Reduce Motion stops the pulse.
- **Known limitation:** from Saved on a slow but not absent connection, the snapshot appears only when the request fails (up to the 15 s timeout).
- **Open questions:** none from this change; the self-check's question 1 is answered by it.
- Status stays `READY_FOR_REVIEW`.

#### S7 review result (2026-11-14)

- The developer reviewed S7 themself and ran independent reviews with Claude and Codex (run by the developer): **no findings** ("everything is fine"). Developer's final approval: **approved**. No individual manual-check results beyond the ones recorded above (keyboard dismissal and its animation, the network log) were shared with the agent; Networking.md § 4's image-cancellation result is still to be recorded there.
- Status → `APPROVED`. The developer merges `feature/release-readiness` into `develop` with `--no-ff`, then `develop` → `main` for the 1.0 release; a later conversation records S7 `COMPLETED` once it confirms the merge. S7 is the last planned stage.

#### S7 merge (recorded by the S8 conversation, 2026-11-14)

- `develop` is at `26dcca2` ("Merge feature/release-readiness (S7: release readiness)", `--no-ff`); `main` is at `aae71db` ("Release 1.0 (S0–S7)", a merge of `develop`). Status → `COMPLETED`. The "Current state" table still said "awaiting merge"; corrected here.

### S8 — Needs attention · READY_FOR_REVIEW (2026-11-14)

- **Branch:** `feature/needs-attention` (from `develop` at `26dcca2`). **Code head:** `b53bc31`; review-gate docs on top. Nothing merged or pushed.
- **Scope:** the developer's S8 request (stage section above). Agent decisions within it, open to override: D-84 (stock policy from `stock`, `availabilityStatus` dropped), D-85 (a scope over loaded products, not a section; no auto-paging in it), D-86 (stock row on cards in both arms), D-87 (details header order), D-88 (fixture launch), D-89 (snapshots keep no stock). Task plan: [plans/S8-needs-attention.md](plans/S8-needs-attention.md).
- **Commits:** `159e319` S7 merge recorded + S8 plan · `12b9a7e` stock policy, `select=…,stock`, analytics `availability` from stock, snapshots without stock · `0b9d6b6` stock row on cards + VoiceOver · `51cd89e` Needs attention scope · `66178ff` details header · `de0e0de` XCUITest target + fixture launch · `f1ee81d` docs · `b53bc31` placeholder refactor (removes a force unwrap) · review-gate docs.
- **Changed files (62):**
  - App: new `Shared/Products/Domain/StockStatus`, `DesignSystem/Components/StockLabel`, `Features/Catalog/Presentation/{CatalogScope, CatalogScopeBar}`, `App/UITesting/{UITestLaunch, FixtureProductRepository}` (DEBUG); changed `Product`, `ProductSummary`, `ProductDTO`, `ProductsTarget`, `ProductInsights`, `SavedProduct`, `AnalyticsEvent`, `AppContext`, `MerchantCatalogApp`, catalog (`CatalogFeed`, `CatalogPhase`, `CatalogViewModel`, `CatalogView`, `CatalogCopy`, card model/view/accessibility), details (`ProductDetailHeader`, `ProductDetailView`, `ProductDetailViewModel`, `ProductFactRow`), `SavedView` (row identifier).
  - Project: target `MerchantCatalogUITests` (`com.apple.product-type.bundle.ui-testing`, bundle id `com.example.MerchantCatalogUITests`, Swift 6, complete concurrency, `TEST_TARGET_NAME = MerchantCatalog`, synchronized folder), second testable in the shared scheme (not parallelized).
  - Tests: new `StockStatusTests`, `StockLabelTests`, `CatalogViewModelAttentionTests` (13), `UITestLaunchTests` (8), `MerchantCatalogUITests/CatalogUITests` (5 UI tests); updated DTO/target/client/repository select pins, card model and label, details header/insights/fact rows, registration (+2), saved snapshot (+1), copy (+3 cases).
  - Docs: README (Needs attention section), ProductSpecification (§ 4.1, 4.3, 4.4, new 4.6, § 7, § 8), Architecture, Analytics (`availability` source; `position` in the scope), Experiments (layout change), Networking (A15, new A16), CLAUDE.md (commands), AILog, this file, the task plan.
- **Build settings** (`xcodebuild -showBuildSettings`, 2026-11-14): unchanged (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation). No packages.
- **Build:** `xcodebuild … clean build` (Debug, iPhone 17, iOS 26.0 Simulator): succeeded; result bundle **0 warnings**, 0 errors, 0 analyzer warnings. `-configuration Release build`: succeeded; 0 warnings, 0 errors. The logs have only the `appintentsmetadataprocessor` "Metadata extraction skipped" tool line. The Release binary contains none of the fixture's strings (`strings` found "Notebook Set"/"ui-testing" 0 times; the Debug dylib 4 times).
- **Tests:** `xcodebuild … test` (unit + UI): **446 passed, 0 failed, 0 skipped** (result bundle summary): 441 Swift Testing tests in 65 suites (+40 test functions since S7's 401) and 5 XCUITests (44.5 s). No compiler warnings in the test log. `git diff --check develop` clean.
- **Red first / mutation checks:** every new suite failed on compilation first (`StockStatus`, `StockLabel`, `AttentionCoverage`/`scopeSelected`, the header's new fields, `FixtureProductRepository`/`UITestLaunch`, `placeholder`). The D-89 test failed on its assertion first (`saved.summary.stock → 4`). Mutations: removing the attention filter and the no-paging guard failed 5 attention unit tests; removing the filter failed `testNeedsAttentionShowsOnlyLowAndOutOfStock` (the in-stock card stayed). The 5 UI tests passed at their first run because the features existed by then; the mutation run shows they detect a broken filter.
- **Manual Simulator checks for the developer** (the agent did not run the app; the UI tests ran through `xcodebuild test` only):
  1. **Launch (live API):** every card shows a stock row under the price ("In stock" in secondary text with a green symbol; "Low stock · 4 left" orange; "Out of stock" red). Page 1 in Default order has 4 attention products (ids 9, 15, 16, 20; from the 2026-11-14 curl data, the API may change): the chip reads "Needs attention 4". Check both experiment arms (Diagnostics override, relaunch): same card height, the rating row only in treatment.
  2. **Needs attention:** tap it: only those cards, the footer "Based on 20 of 194 products loaded so far." and **Load more products**; tap it: spinner, then the count and list grow. All products: every card again. Scroll in All products: the count grows as pages load. Over the whole catalog the policy finds 28 (24 low, 4 out).
  3. **Attention edge cases:** Needs attention with the network off, Load more: message + Retry in the footer; network on, Retry. Pull to refresh in the scope: the list stays filtered. A sort change: skeleton, then the scope still applied.
  4. **Search:** "phone" with Needs attention selected: only the attention results; Cancel: browse returns in the scope it had.
  5. **Details:** title, price, stock badge, category · brand, rating at the top; At a Glance without rating/availability; Pricing only with a discount; Shipping & availability shows "Availability: Low stock" and the units. Skeleton unchanged otherwise.
  6. **Saved:** save a low-stock product, network off, open it from Saved: the snapshot without a stock badge (D-89). Products saved before S8 still load (unchanged file format).
  7. **Accessibility:** VoiceOver on a card: "Title, $price, Low stock, 4 left, [rated …,] not saved"; the chips: "Needs attention, 4 products, button" (+ "selected"); the details badge reads its text. Largest Dynamic Type (AX5): the chips stack, the stock row stays one line (truncates if needed). Dark mode: the badge and chips legible.
  8. **UI tests in Xcode:** ⌘U runs 446 tests including the 5 UI tests (the app launches in the Simulator with fixture products: Desk Lamp, Notebook Set, Travel Mug, Wireless Mouse).
  9. **Release build:** Edit Scheme → Run → Release: the app runs against the API (no fixture path).
- **Known limitations:**
  - Needs attention counts only loaded products (no inventory endpoint or stock filter in the API); the count is complete only when every page of the list is loaded, and the UI says so.
  - In the scope, `product_selected` / `product_saved` `position` is the index in the loaded list, and no event or property records the scope (Analytics.md notes it).
  - The search field and the Saved tab have no accessibility identifier (SwiftUI's `.searchable` and tab bar take none); the UI tests use the only search field and the tab title.
  - The UI tests don't pin the card experiment's variant (a fresh installation is hashed each launch); they don't read the rating, and both arms have the same height (D-21).
  - The stock row's colors, truncation at large text, the chips' stacking and VoiceOver reading are SwiftUI rendering, checked manually (no snapshot tests).
  - Built with Xcode 26.0, not the current 27.2 (D-1).
- **Open questions for the developer:**
  1. Track Needs attention? A minimal option: `catalog_scope_changed { scope, attention_count, loaded_count }` and a `scope` property on `product_selected` / `product_saved`. Left out because the request kept analytics out of the product story.
  2. Agent decisions D-84–D-89 (above), in particular: the scope over a section (D-85), dropping `availabilityStatus` everywhere including analytics (D-84), and 10 as the low-stock limit (from the request).
- **Findings and resolution:** awaiting the developer's Codex review.

#### S8 review — findings and resolution (2026-11-14)

The developer shared three findings from the review of `ad194b2`. All three accepted; status `CHANGES_REQUESTED` → fixes on the same branch → `READY_FOR_REVIEW`.

1. **Coverage claimed "all" after an empty page** (accepted, defect). `CatalogFeed.coverage` used `!list.canLoadMore`, which also turns false after an empty page while `nextSkip < total`, so the footer could say "Based on all 20 products." with 174 never loaded. Fix `d41ab2a`: complete only when `pagesLoaded > 0 && nextSkip >= total`; paging, the footer's end state and Retry unchanged, no request added. Test first: `coverageIsNotCompleteAfterAnEmptyPageBeforeTheEnd` failed (`isComplete: true`), then passed.
2. **Analytics positions in Needs attention came from the unfiltered list** (accepted, defect). `cardSelected` and `saveToggled` indexed `feed.list.items`. Fix `b16fb72`: both count `CatalogFeed.cards(in: scope)`, the cards on screen; saving still stores the loaded `ProductSummary`; a card outside the scope is ignored like one of a hidden list. All products and search keep their positions (the cards there are the loaded list, 1:1). Analytics.md updated in the same commit. Tests first, each failed on the old position: `selectingInNeedsAttentionReportsTheVisiblePosition` (id 9 → 3, was 8), `savingInNeedsAttentionReportsTheVisiblePosition` (position 3, the loaded snapshot), `positionsAfterPaginationCountTheListOnScreen` (id 40 → 39 in All products, 8 in the scope), `searchResultsInNeedsAttentionReportTheVisiblePosition` (104 → 1, hidden browse card ignored), `cardOutsideTheScopeIsIgnored`. The S8 gate's known limitation about `position` no longer applies; the scope is still not recorded on the events (open question 1 stands).
3. **Stock copy inconsistent** (accepted, docs). The code and tests already used "Low stock · 4 left" on screen and "Low stock, 4 left" for VoiceOver; the task plan had a lowercase "low stock, 4 left" label and ProductSpecification § 4.5 gave a product that is in stock (stock 99 in the 2026-11-14 data) a low-stock reading. Fix `8ca9eca`: § 4.1 names both forms (spoken form canonical), § 4.5's example corrected, the plan and README aligned, `StockLabelTests` pins the 4-left case. No visible text changed.

- **Verification** (2026-11-14, after the fixes): `git diff --check` and `git diff --check develop..HEAD` clean. `xcodebuild … clean build` (Debug): succeeded, result bundle 0 warnings / 0 errors / 0 analyzer warnings. `xcodebuild … test`: **452 passed, 0 failed, 0 skipped** (447 Swift Testing tests in 65 suites, +6; 5 XCUITests, 43.9 s); no compiler warnings in the test log.
- **No live network in the UI tests:** shown by code paths, not by a network capture. Only `LiveProductRepository` uses `APIClientType`; with `-ui-testing` the registered repository is `FixtureProductRepository` (`UITestLaunchTests.contextUsesTheFixture`); fixture products have no thumbnail or image URLs, and `ProductImageModel.load` returns before calling the loader for a `nil` URL. Reading the simulator's unified log to confirm it at run time was not permitted in this session.
- **Not changed:** basket, inventory, ordering, the analytics architecture (no new event or property), navigation.
