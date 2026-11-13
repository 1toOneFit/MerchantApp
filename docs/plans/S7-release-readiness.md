# S7 — Release Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a coherent, accessible, honestly documented 1.0: the catalog grid drops to one column at accessibility text sizes, every standalone control is a ≥ 44 pt target, the taxonomy is final, and README, Architecture, ProductSpecification, AILog and the plan describe the app as built, including the release criteria that are not met.

**Architecture:** one pure layout rule, `CatalogLayout.columnCount(for: DynamicTypeSize)`, read by the grid and the skeleton through `@Environment(\.dynamicTypeSize)`. Tap-target fixes are view-only (no logic): large control size for bordered buttons, and the 44 pt frame inside the label for icon buttons. Everything else is tests that lock existing behavior (card label, final taxonomy) and documentation.

**Tech Stack:** Xcode 26.0, Swift 6 language mode (strict concurrency complete, no default isolation), SwiftUI iOS 26.0, Swift Testing. No packages.

**Spec:** [ImplementationPlan.md § S7](../ImplementationPlan.md#s7--release-readiness), [MasterSpecification.md § 1](../MasterSpecification.md#1-product-intent-and-success-definition) (release completion criteria) and § 10 (README expectations), [ProductSpecification.md § 4.5](../ProductSpecification.md#45-resilience-and-accessibility), [Analytics.md](../Analytics.md), [Architecture.md](../Architecture.md), [AILog.md](../AILog.md). Builds on [S6](S6-card-rating-experiment.md).

## Global Constraints

- Neutral naming only (`MerchantCatalog`). No third-party dependencies. No caching (D-10). No UI snapshot tests.
- Developer decisions at the S7 scope confirmation (2026-11-13): one column at every accessibility size (`isAccessibilitySize`, AX1–AX5), two otherwise; card label tests over all four rating/saved combinations plus the 44 pt fixes, dark mode audited without code change; README gets a "Release status" table of the MasterSpecification § 1 criteria (met / met with a trade-off / pending the developer's manual check); the four carried-over open questions are closed as "kept as built".
- AILog holds only real entries: S6's recorded scope decisions and Codex findings, S7's scope decisions. Nothing reconstructed or invented.
- No fabricated results: the image-cancellation check (Networking.md § 4) and the Simulator smoke checks stay "pending the developer" unless the developer reports a result.
- Analytics code and Analytics.md change in the same commit (S7 adds no event).
- Verification: `xcodebuild build` (Debug and Release, 0 warnings via `xcrun xcresulttool get build-results`) and `xcodebuild test` (test log free of compiler warnings). The agent never runs the app in the Simulator.

## Review Focus

1. At an accessibility size the skeleton must match the grid (one column), or the first load jumps from 2 to 1 column. Both read `CatalogLayout.columns(for:)` (Task 2).
2. Every `DynamicTypeSize` case must map to a column count, including `.xSmall` and `.accessibility5`; a future case defaults through `isAccessibilitySize`. `columnCountFollowsAccessibilitySizes` is parameterized over `DynamicTypeSize.allCases` (Task 2).
3. A `.frame(minHeight: 44)` outside a bordered or borderless button grows its layout, not its hit area (expected SwiftUI behavior, checked manually): the fixes size the button itself (Task 3).
4. The rating in the card label uses one fraction digit in the given locale ("4,6" in `de_DE`), as the visible "★ 4.6" does in English. `labelUsesTheLocalesDecimalSeparator` (Task 1).
5. A later edit that sets an event back to Planned or reintroduces a removed event must fail. `everyDocumentedEventIsActive`, `removedEventsStayOutOfCode` (Task 4).

---

### Task 1: Card accessibility label — all combinations

**Files:** Modify `MerchantCatalogTests/Features/Catalog/ProductCardAccessibilityTests.swift`. No app change expected (`ProductCardAccessibility.label` exists since S5).

- [ ] **Step 1:** Replace `labelWithoutRating` and `labelWithRatingWhenSaved` with one parameterized `labelCombinesTitlePriceRatingAndSavedState(rating:isSaved:expected:)` over `(nil, false, "Volume Mascara, $9.99, not saved")`, `(nil, true, "Volume Mascara, $9.99, saved")`, `(4.56, false, "Volume Mascara, $9.99, rated 4.6 of 5, not saved")`, `(4.56, true, "Volume Mascara, $9.99, rated 4.6 of 5, saved")` with `en_US`. Add `labelUsesTheLocalesDecimalSeparator`: `de_DE`, rating 4.56 → contains `"rated 4,6 of 5"`.
- [ ] **Step 2:** Run the suite: expected PASS on the first run (behavior exists). Mutation-check: temporarily drop the `isSaved` part from `label`, see the saved cases fail, revert.
- [ ] **Step 3:** Commit `test: cover every card accessibility label combination`.

### Task 2: One grid column at accessibility sizes

**Files:** Create `MerchantCatalog/Features/Catalog/Presentation/CatalogLayout.swift` (move the private `CatalogLayout` out of `CatalogView.swift`); modify `CatalogView.swift` (`CatalogGrid`, `CatalogSkeletonGrid`); Test `MerchantCatalogTests/Features/Catalog/CatalogLayoutTests.swift`.

**Interfaces — Produces:**
- `enum CatalogLayout { static func columnCount(for size: DynamicTypeSize) -> Int; static func columns(for size: DynamicTypeSize) -> [GridItem]; static let rowSpacing: CGFloat }` (nonisolated: not a `View`).

- [ ] **Step 1:** Write `CatalogLayoutTests`: `columnCountFollowsAccessibilitySizes(size:)` over `DynamicTypeSize.allCases`: `#expect(CatalogLayout.columnCount(for: size) == (size.isAccessibilitySize ? 1 : 2))`; `defaultAndLargestNonAccessibilitySizesUseTwoColumns`: `.large` → 2, `.xxxLarge` → 2; `accessibilitySizesUseOneColumn`: `.accessibility1` → 1, `.accessibility5` → 1; `columnsMatchTheCount`: `columns(for: .large).count == 2`, `columns(for: .accessibility3).count == 1`.
- [ ] **Step 2:** Run: FAIL to compile (`CatalogLayout` is private / no `columnCount`).
- [ ] **Step 3:** Implement: `columnCount` = `size.isAccessibilitySize ? 1 : 2`; `columns(for:)` = that many `GridItem(.flexible(), spacing: 12, alignment: .top)`; `rowSpacing = 20`. `CatalogGrid` and `CatalogSkeletonGrid` read `@Environment(\.dynamicTypeSize)` and pass it to `columns(for:)`.
- [ ] **Step 4:** Run the suite: PASS. Mutation-check: `>= .accessibility2` instead of `isAccessibilitySize` → `.accessibility1` case fails; revert.
- [ ] **Step 5:** Commit `feat: switch the catalog grid to one column at accessibility sizes` (with D-75 in the plan's Decisions table).

### Task 3: 44 pt tap targets

**Files:** Modify `CatalogView.swift` (empty/no-results/failed actions, page footer Retry), `Features/Saved/Presentation/SavedView.swift` (Browse catalog), `Features/ProductDetail/Presentation/ProductDetailView.swift` (banner Retry), `DesignSystem/Components/ErrorBanner.swift` (Dismiss).

No unit test: views have no unit tests in this project and SwiftUI hit areas aren't observable from one. Each change is a manual check for the developer (Accessibility Inspector shows each element's frame).

- [ ] **Step 1:** Bordered buttons (`Reload`, `Clear search`, full-screen `Retry`, footer `Retry`, `Browse catalog`, details banner `Retry`): add `.controlSize(.large)`; remove the details banner's outer `.frame(minHeight: 44)`. Expected: large bordered buttons are about 50 pt tall on iOS (expected, not measured).
- [ ] **Step 2:** `ErrorBanner` Dismiss: label `Image(systemName: "xmark").frame(width: 44, height: 44).contentShape(.rect)` inside `Button`, `.accessibilityLabel("Dismiss")`, like `CardSaveButton`.
- [ ] **Step 3:** Build Debug: 0 warnings; run the tests: green. Commit `fix: make standalone buttons at least 44 pt` (D-76).

### Task 4: Final taxonomy

**Files:** Modify `MerchantCatalogTests/Core/Analytics/TaxonomyDocumentationTests.swift`, `docs/Analytics.md` (header: as of 1.0 every event is Active; removed candidates in § 4).

- [ ] **Step 1:** Add `everyDocumentedEventIsActive`: every parsed event's status == `"Active"` (names listed on failure). Add `removedEventsStayOutOfCode`: the names in Analytics.md § 4 rows whose decision starts with `**Removed` (parsed: first column's backticked name) are non-empty and disjoint from `AnalyticsEventName` raw values.
- [ ] **Step 2:** Run: expected PASS (S6 made the last event Active; `sort_options_opened` was removed in S3). Mutation-check: set one heading to `Planned (S7)` → `everyDocumentedEventIsActive` fails; add `case sortOptionsOpened = "sort_options_opened"` temporarily → `removedEventsStayOutOfCode` fails; revert both.
- [ ] **Step 3:** Update the Analytics.md header and the test's doc comment. Commit test + Analytics.md together `test: lock the final analytics taxonomy`.

### Task 5: Docs reconciled with the code

**Files:** `docs/Architecture.md`, `docs/ProductSpecification.md`, `docs/ImplementationPlan.md` (Decisions D-75–D-77), `docs/AILog.md`, `README.md`.

- [ ] **Step 1: Architecture.** § 2 tree = the files on disk (`AppTab` under `Core/Navigation`; no `Core/Persistence`, no `DesignSystem/Theme`; add `CatalogCopy`, `CatalogLayout`, `ProductCardAccessibility`, `SavedRowModel`, `SavedProductFormat`, `Support/{TemporaryDirectory, CardExperiments}`); add "What exists (S7)"; § 7 `Route` comment matches the enum route; § 11 lists `CatalogLayoutTests`. Check with `git ls-files`.
- [ ] **Step 2: ProductSpecification § 4.5** "as built (S7)": the column rule, large-size buttons, dark mode by system colors and materials only.
- [ ] **Step 3: Decisions.** D-75 column rule (Developer, S7 scope). D-76 44 pt approach (Agent). D-77 the four open questions closed, behavior kept as built (Developer, S7 scope).
- [ ] **Step 4: AILog.** S6: scope recommendations D-69–D-72 accepted; Codex found the Diagnostics header and the stale "★ 4.6" text, both fixed. S7: scope recommendations accepted. Only what the plan's review log records.
- [ ] **Step 5: README** (about one page): what 1.0 does (as built, incl. accessibility), requirements and running, key decisions, caching, deliberately left out, measuring, AI assistance (real examples), **Release status** table against MasterSpecification § 1, known limitations (incl. the closed open questions), Documentation Index (+ `docs/plans/`). No time spent.
- [ ] **Step 6:** `git diff --check`; commit `docs: finalize README and reconcile docs for 1.0`.

### Task 6: Review gate

- [ ] Clean Debug build + Release build (0 warnings via `xcresulttool`), `xcodebuild test` (counts from the result bundle, test log grep for `warning:`).
- [ ] Review log entry with the full smoke checklist (browse, paginate, refresh, offline, search, sort, details, save/unsave, relaunch, Saved offline, experiment overrides, Diagnostics, VoiceOver, largest Dynamic Type, dark mode, 44 pt targets, image cancellation).
- [ ] Status `READY_FOR_REVIEW`, Current state, hand-over note, then the review sentence and stop.

## Deviations found during implementation

- **Task 1:** the tests passed on the first run, as expected (the label exists since S5). Mutation-checked twice: a label that always says "not saved" failed the two saved cases; dropping `.locale(locale)` failed the locale test.
- **Task 2:** red on compilation (`CatalogLayout` was private to `CatalogView.swift`). Mutation `size >= .accessibility2` failed the `.accessibility1` cases of both tests.
- **Task 3:** as planned, plus the details banner's Retry lost its outer `.frame(minHeight: 44)`, which grew the layout but not the hit area (D-76). Verified only by build and the full test run; hit areas are a manual check.
- **Task 4:** the new tests passed on the first run (expected). Mutation-checked by editing Analytics.md: `search_cleared` set to `Planned (S7)` failed `everyDocumentedEventIsActive` (and the existing Active/Planned tests); the removed row renamed to `search_failed` failed both expectations of `removedEventsStayOutOfCode`. The planned mutation of adding a `sort_options_opened` case in code wasn't used: a new enum case would first break the exhaustive switches, a compile error rather than this test's failure.
- **Task 5:** the README's "Runs" row says the agent never ran the app and points to the manual checks, rather than claiming they were done: no manual-check results have been shared with the agent.
- **Developer change request at the gate (D-78):** replace `AsyncImage` with explicit image cancellation. Done test-first on this branch (`fe0b79f`, `3c09319`, `e655c6b`); details in the review log's "S7 developer change request" entry.
