# Implementation Plan and Status

This file is the **persistent source of truth for progress**. A fresh conversation resumes from here (see [CLAUDE.md](../CLAUDE.md) → startup protocol). Keep it accurate before ending any conversation.

## Current state

| Field | Value |
|---|---|
| Phase | **PLANNING COMPLETE — plan approved by the developer on 2026-11-13** |
| Current stage | — |
| Current branch | `develop` (created from the initial planning commit on `main`) |
| Last completed stage | Planning (docs committed to `main` as the initial commit) |
| Next authorized stage | **S0 — Project foundation** (`feature/project-foundation` from `develop`), to start in a new conversation |
| Pending human action | Start a new Claude Code conversation for S0 |
| Open review findings | — |
| Blockers | — |

## Stage status

Statuses: `PLANNED` → `IN_PROGRESS` → `READY_FOR_REVIEW` → (`CHANGES_REQUESTED` → `READY_FOR_REVIEW`)* → `APPROVED` → `COMPLETED` (merged into `develop` by the developer).

| ID | Stage | Branch | Status | Head commit | Review |
|---|---|---|---|---|---|
| S0 | Project foundation | `feature/project-foundation` | PLANNED | — | — |
| S1 | Analytics core & diagnostics | `feature/analytics-core` | PLANNED | — | — |
| S2 | Catalog browsing, networking & images | `feature/catalog-browse` | PLANNED | — | — |
| S3 | Search & sort | `feature/search-sort` | PLANNED | — | — |
| S4 | Product details | `feature/product-details` | PLANNED | — | — |
| S5 | Saved products | `feature/saved-products` | PLANNED | — | — |
| S6 | Card rating experiment | `feature/card-rating-experiment` | PLANNED | — | — |
| S7 | Release readiness | `feature/release-readiness` | PLANNED | — | — |

The stages run strictly in order, S0 → S7. Each stage branches from `develop` **after** the previous stage was approved and merged into `develop` by the developer.

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
  - Accessibility pass: VoiceOver card labels with a save custom action, Dynamic Type with a 1-column grid at accessibility sizes, 44 pt targets, dark mode.
  - Final taxonomy reconciliation: every event Active or explicitly removed.
  - README finalized to about one page with the Documentation Index.
  - [AILog.md](AILog.md) completed with real entries; all docs reconciled with the code.
- **Tests first:** card accessibility-label composition (with/without rating, saved/not saved); grid column count by Dynamic Type size.
- **Acceptance:** the release completion criteria in [MasterSpecification.md § 1](MasterSpecification.md#1-product-intent-and-success-definition) are met or explicitly documented as not met.
- **Manual checks (developer):** full smoke checklist (browse, paginate, refresh, offline, search, sort, details, save/unsave, relaunch, Saved offline, experiment overrides, Diagnostics, VoiceOver, largest Dynamic Type).
- **Release:** after approval, the developer merges into `develop` and then `develop` → `main`.

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
| D-8 | Two tabs, one stack and router per tab | Developer | Agent recommendation. |
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
| D-23 | `AsyncImage` (no custom image loader), shown only while the cell is visible: load on appear, torn down on disappear | Developer | Replaces the custom `ImageLoader`; the former image-loading stage was folded into S2. |
| D-24 | Protocol-first infrastructure: `APIClientType`, `AnalyticsTracking` + `AnalyticsProvider`, repository and experiment protocols; only `AppContext` names concrete types | Developer | Swap or add implementations (e.g. another analytics vendor) without changing protocols or callers. |
| D-25 | The agent verifies with build + tests only and never runs the app in the Simulator; the developer does manual Simulator checks | Developer | Token cost. |

Decisions marked "Agent" are open to the developer's override during plan review.

## Review log

*(One entry per stage at each review gate: branch, head commit, changed files, tests, build warnings, manual checks for the developer and their results, limitations, open questions, findings and their resolution.)*
