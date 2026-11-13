# S3 — Search and Sort Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merchants search the catalog (debounced, server-side, stale-safe) and sort browse or search results server-side, with an instant return to the previous browse list and the five search/sort analytics events.

**Architecture:** `CatalogViewModel` holds two lists, browse and the current search, each a `CatalogFeed` value with its own `CatalogListState`, sort, generation and load status. The screen shows the search feed while one exists, otherwise browse. Search page 1 runs in a view-model-owned `searchTask` that first sleeps 300 ms on the injected clock; every page-1 load stamps its feed with a new generation, so a stale result is dropped even if cancellation loses the race. `CatalogView` keeps the browse grid alive (hidden) under the search results, so clearing restores it exactly.

**Tech Stack:** Xcode 26.0, Swift 6.2 compiler in Swift 6 language mode, SwiftUI (iOS 26.0), Observation, `Synchronization.Mutex`, Swift Testing. No packages.

**Spec:** [ImplementationPlan.md § S3](../ImplementationPlan.md#s3--search-and-sort), [ProductSpecification.md § 4.2](../ProductSpecification.md#42-search-and-sort), [Analytics.md § 3 Search, Sorting](../Analytics.md#search), [Networking.md A2–A5, § 2](../Networking.md), [Architecture.md § 5, § 8](../Architecture.md). Builds on [S2](S2-catalog-browse.md).

## Global Constraints

- Neutral naming only (`MerchantCatalog`). No third-party dependencies. No caching (D-10).
- `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation (D-31). Verified on this branch with `-showBuildSettings` (2026-11-13).
- Debounce **300 ms** after the last keystroke, on the injected `any Clock<Duration>` (D-40). Leading/trailing whitespace trimmed; an empty query returns to browse.
- The app **never sorts locally**. Sort options, exact copy: **Default**, **Price: Low to High**, **Price: High to Low**, **Rating: High to Low**. Sort is not persisted (D-22).
- No-results copy: `No products match "<query>"` with a **Clear search** action. Search prompt: "Search products".
- D-18: no query text in analytics or logs (`NetworkLogger` already redacts `q`).
- Task lifecycle as in S2: tasks started from synchronous callbacks are view-model-owned, fetch through the static helper without referencing the view model, apply results through `[weak self]`; `isolated deinit` cancels all of them. Cancellation is never an error.
- `NavigationStack` / `navigationDestination` only in `App/AppTabView.swift`; `AppTabView` owns no feature view model.
- Analytics code and `docs/Analytics.md` change in the same commit.
- Verify with `xcodebuild build` (0 warnings in the result bundle; Release too) and `xcodebuild test` on `platform=iOS Simulator,name=iPhone 17,OS=26.0`. Never launch or drive the app in the Simulator.

## Decisions taken in this plan

| ID | Decision | By | Why |
|---|---|---|---|
| D-44 | The sort control is a toolbar `Menu` with a `Picker`; `sort_options_opened` is removed from code and Analytics.md | Developer (scope) | SwiftUI's `Menu` has no open signal: the iOS 26.0 SDK `SwiftUI.swiftinterface` declares only content/label/`primaryAction` initializers (checked 2026-11-13). `primaryAction` replaces the tap, so it can't be used. |
| D-45 | A sort change shows the skeleton until page 1 of the new order arrives (new results start at the top); a failure shows the full-screen error. `has_visible_content` = products were on screen when the request started | Developer (scope) | The label and the order on screen never disagree. |
| D-46 | Sort belongs to each list: a search starts with the sort on screen; a sort change while searching changes only the search; clearing restores browse with its own sort, without a request | Developer (scope) | AC-S4: the exact previous browse state. |
| D-47 | The browse grid stays in the hierarchy, hidden and inert, under the search results; the Catalog title is inline and the search field always visible | Developer (scope) | Exact scroll position and loaded thumbnails on clear, with no scroll code. With two scroll views a large title might track the hidden one (expected, not verified). |
| D-48 | Search events use their own trigger (`typing`, `retry`, `sort_change`). A search pull-to-refresh sends only `catalog_refreshed` (`list_context: search`); search pages use `catalog_page_*` with `list_context: search`; their footer Retry is `failed_surface: catalog_page` | Agent | Same rules as browse (D-41); one event per meaning. |
| D-49 | `query_length` = characters of the trimmed query; `word_count` = whitespace-separated words; `had_results` = the search list on screen had ≥ 1 product. `search_started` / `search_cleared` fire when the trimmed query turns non-empty / empty | Agent | Defines the properties Analytics.md leaves open; whitespace alone is not a search. |
| D-50 | During the 300 ms debounce the current list stays on screen; a committed query shows the skeleton; an edit that leaves the trimmed query unchanged (e.g. a trailing space) sends nothing | Agent | No result for a query is ever shown under another query once it loads. |
| D-51 | A `+` in a query value is sent as `%2B` | Agent | The API decodes `+` as a space (A13); `URLComponents` leaves `+` unencoded. |
| D-52 | Task handles per list: `firstPageTask` (browse page 1 from taps), `searchTask` (search page 1), one page ≥ 2 task per list. A hidden list's in-flight load finishes in the background. `itemAppeared(id:in:)` names its list and is ignored for the hidden one | Agent | One request per list at a time; the hidden browse layer's cards can't trigger search pagination. |

## Review Focus

1. **A query with `+`, `&`, `=` or spaces** → the server receives the literal text → Task 1 `searchQueryIsPercentEncoded`.
2. **Typing again exactly when the 300 ms elapse** (the old debounce has woken but not run) → only the newest query is requested → Task 6 `retypingAtTheDeadlineRequestsOnlyTheLatestQuery`.
3. **Clearing while a search request is in flight** → its late response never appears and sends no event → Task 6 `clearingDropsAnInFlightSearch`.
4. **A browse page in flight when a search starts** → it lands in browse only, visible after clearing → Task 6 `browsePageFinishesWhileSearching`.
5. **A sort change during a pull-to-refresh** → the refresh result is dropped, the new sort wins, load-more works afterwards → Task 5 `sortChangeDuringRefreshWins`.

---

### Task 1: Search endpoint and query encoding

**Files:** Modify `MerchantCatalog/Shared/Products/Data/ProductsTarget.swift`, `MerchantCatalog/Networking/URLSessionAPIClient.swift` (`makeRequest`); Test `MerchantCatalogTests/Shared/Products/ProductsTargetTests.swift`, `MerchantCatalogTests/Networking/URLSessionAPIClientTests.swift`; Docs `docs/Networking.md` (A13, § 2 as built).

**Interfaces — Produces:** `ProductsTarget.search(query: String, skip: Int, limit: Int, sort: ProductSort)` — path `/products/search`; query items in order `q`, `limit`, `skip`, then the sort items. `makeRequest` sends `+` as `%2B`.

- [x] **Step 1: Write failing tests.** `searchQueryItems` (parameterized over the four sorts): `.search(query: "phone", skip: 20, limit: 20, sort:)` → `[q=phone, limit=20, skip=20] + sortItems`. `searchPath`: `/products/search`, `.get`. `buildsSearchRequestWithSortAndPage` (AC-S3): `makeRequest(for: .search(query: "phone", skip: 20, limit: 20, sort: .priceDescending), delay: nil).url?.absoluteString == "https://dummyjson.com/products/search?q=phone&limit=20&skip=20&sortBy=price&order=desc"`. `searchQueryIsPercentEncoded`: query `"a+b & c=d"`, `skip 0`, default sort → `…/products/search?q=a%2Bb%20%26%20c%3Dd&limit=20&skip=0`.
- [x] **Step 2:** Run → compile failure (no `.search`).
- [x] **Step 3:** Implement; after setting `queryItems`, replace `+` with `%2B` in `percentEncodedQuery`. Add A13 to Networking.md (curl 2026-11-13: `q=iphone+charger` and `q=iphone%20charger` → total 1, `q=iphone%2Bcharger` → 0).
- [x] **Step 4:** Run → pass (`searchQueryIsPercentEncoded` must fail before the `%2B` line: check by running it once before adding the line).
- [x] **Step 5:** Commit `feat: add ProductsTarget.search`.

### Task 2: Repository search and fake support

**Files:** Modify `Shared/Products/Domain/ProductRepository.swift`, `Shared/Products/Data/LiveProductRepository.swift`, `MerchantCatalogTests/Fakes/FakeProductRepository.swift`; Test `LiveProductRepositoryTests.swift`.

**Interfaces — Produces:**
- `ProductRepository.search(query: String, sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage` (`@concurrent` in `LiveProductRepository`).
- `FakeProductRepository.Request` gains `var query: String? = nil` declared first (existing `.init(sort:skip:limit:)` calls keep compiling); `search(...)` records `Request(query:sort:skip:limit:)` and answers like `products`; `func resumeNewest(with:)` answers the most recently suspended request.

- [x] **Step 1: Write failing test** `requestsSearchTargetAndMapsPage` (path `/products/search`, items `q=phone, limit=20, skip=40, sortBy=rating, order=desc`; page equals the DTO's `toDomain()`).
- [x] **Step 2:** Run → compile failure.
- [x] **Step 3:** Implement (protocol, live repository, fake).
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add product search to the repository`.

### Task 3: SearchQuery

**Files:** Create `MerchantCatalog/Features/Catalog/Domain/SearchQuery.swift`; Test `MerchantCatalogTests/Features/Catalog/SearchQueryTests.swift`.

**Interfaces — Produces:** `struct SearchQuery: Equatable, Sendable { let text: String; init?(_ rawText: String); var length: Int; var wordCount: Int }` — `text` trimmed of `.whitespacesAndNewlines`; `nil` when nothing is left; `length = text.count`; `wordCount` = whitespace-separated non-empty parts (D-49).

- [x] **Step 1: Write failing tests:** `trimsWhitespace` (`"  phone \n"` → `"phone"`); `blankIsNil` (parameterized: `""`, `"   "`, `"\n\t"`); `lengthAndWordCount` (parameterized: `"phone"` → 5/1, `"red  shoes"` → 10/2, `"  café  latte\n"` → 11/2).
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add SearchQuery`.

### Task 4: Deterministic TestClock sleeping

**Files:** Modify `MerchantCatalogTests/Support/TestClock.swift`; Test `MerchantCatalogTests/Support/TestClockTests.swift`.

**Interfaces — Produces:** `sleep(until:tolerance:)` suspends until `advance(by:)` reaches the deadline (a deadline already reached returns at once); cancellation throws `CancellationError` (also when cancelled before suspending); `var sleeperCount: Int`; `func waitForSleepers(_ count: Int) async` (continuation, no polling). State in one `Mutex`; continuations are resumed outside the lock.

- [x] **Step 1: Write failing tests:** `sleepEndsAtTheDeadline` (task sleeps 300 ms; `waitForSleepers(1)`; `advance(299 ms)` → `sleeperCount == 1`; `advance(1 ms)` → the task finishes without error); `cancelledSleepThrows` (cancel while sleeping → `CancellationError`, `sleeperCount == 0`); `pastDeadlineReturnsAtOnce`.
- [x] **Step 2:** Run → fail (the current `sleep` records an issue). **Step 3:** Implement. **Step 4:** Run → pass.
- [x] **Step 5:** Commit `test: add deterministic sleeping to TestClock`.

### Task 5: Search and sort analytics events

**Files:** Modify `MerchantCatalog/Core/Analytics/AnalyticsEvent.swift`, `docs/Analytics.md`; Test `MerchantCatalogTests/Core/Analytics/SearchAnalyticsEventTests.swift`.

**Interfaces — Produces:**
- `ListContext` + `search`; `CatalogLoadTrigger` + `sortChange = "sort_change"`; `FailedSurface` + `search`; new `enum SearchTrigger: String, Sendable { case typing, retry, sortChange = "sort_change" }`.
- New names/cases: `.searchStarted(sort: ProductSort)`, `.searchPerformed(trigger: SearchTrigger, queryLength: Int, wordCount: Int, sort: ProductSort, resultCount: Int, totalCount: Int, durationMs: Int)`, `.searchFailed(trigger: SearchTrigger, queryLength: Int, error: AppError)`, `.searchCleared(queryLength: Int, hadResults: Bool)`, `.sortChanged(from: ProductSort, to: ProductSort, listContext: ListContext)` → `from_sort`, `to_sort`, `list_context`.
- Analytics.md: the five events **Active** with D-48/D-49 notes; `sort_options_opened` heading removed and § 4's row says why (D-44); `has_visible_content` defined (D-45); `list_context: search` noted on `catalog_viewed`, `catalog_refreshed`, `catalog_page_*`.

- [x] **Step 1: Write failing tests:** one row per new case with exact dictionaries, e.g. `.searchPerformed(trigger: .typing, queryLength: 5, wordCount: 1, sort: .priceAscending, resultCount: 20, totalCount: 23, durationMs: 140)` → `["trigger": "typing", "query_length": 5, "word_count": 1, "sort": "price_asc", "result_count": 20, "total_count": 23, "duration_ms": 140]`; `.searchFailed(trigger: .retry, queryLength: 3, error: .offline)` → `["trigger": "retry", "query_length": 3, "error_type": "offline"]`; `.searchCleared(queryLength: 5, hadResults: false)`; `.sortChanged(from: .defaultOrder, to: .ratingDescending, listContext: .search)`; plus `.catalogLoadCompleted(trigger: .sortChange, …)`, `.catalogPageRequested(listContext: .search, …)`, `.retryRequested(failedSurface: .search, error: .timeout)`.
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement code and docs. **Step 4:** Run → pass, `TaxonomyDocumentationTests` included.
- [x] **Step 5:** Commit `feat: add search and sort analytics events`.

### Task 6: Lists per feed, then search

Two commits: a behavior-preserving refactor, then search.

**Files:** Create `MerchantCatalog/Features/Catalog/Presentation/CatalogFeed.swift`; Modify `CatalogViewModel.swift`, `CatalogPhase.swift`; Test `CatalogViewModelTests.swift` (call sites), new `MerchantCatalogTests/Features/Catalog/CatalogViewModelSearchTests.swift`.

**Interfaces — Produces:**
- `struct CatalogFeed` (internal, used only by the view model): `query: SearchQuery?` (nil = browse), `sort`, `generation`, `list: CatalogListState`, `cards`, first-page and page-load status, `refreshError`; `var context: ListContext`; `var content: CatalogListContent`.
- `CatalogPhase` + `case noResults(query: String)`. `struct CatalogListContent: Equatable { let phase: CatalogPhase; let cards: [ProductCardModel] }`.
- `CatalogViewModel`: `static let searchDebounce: Duration = .milliseconds(300)`; `private(set) var searchText: String`; `var sort: ProductSort`, `var listContext: ListContext`, `var phase`, `var cards` (all of the list on screen); `var browseList: CatalogListContent`; `var searchList: CatalogListContent?`; `func searchTextChanged(to text: String)`; `func clearSearch()`; `func itemAppeared(id: Product.ID, in context: ListContext)` (replaces `itemAppeared(id:)`); `private(set) var searchTask: Task<Void, Never>?`; `var pageTask` (the list on screen). Existing intents act on the list on screen.

- [x] **Step 1 (refactor):** Move browse state into `CatalogFeed` and the generation check to "the feed for this load still has this generation"; change `itemAppeared` call sites to `in: .browse`. Run the suite → all 153 green. Commit `refactor: hold catalog list state per feed`.
- [x] **Step 2: Write failing tests** (`CatalogViewModelSearchTests`; helpers `type(_:)` and `commit()` = `waitForSleepers(1)` + `advance(by: 300 ms)` + await `searchTask`):
  - `requestsOnlyTheLastQueryAfterTypingStops` (AC-S1): "p", "ph", "pho", "phon", "phone" with 100 ms between → no request; 300 ms after the last → exactly `[Request(query: "phone", sort: .defaultOrder, skip: 0, limit: 20)]`.
  - `queryIsTrimmed` ("  phone  " → `query: "phone"`); `whitespaceOnlyStaysInBrowse` (no request, no event, `listContext == .browse`); `trailingSpaceSendsNothing` (after "phone" loaded, "phone " → no request).
  - `committedQueryShowsSkeletonThenResults` (during the debounce `phase` is still browse content; after commit `.initialLoading` with `listContext == .search`; then 20 cards); event `.searchPerformed(trigger: .typing, queryLength: 5, wordCount: 1, sort: .defaultOrder, resultCount: 20, totalCount: 23, durationMs: 140)`.
  - `outOfOrderResponseIsDropped` (AC-S2): "ph" committed and pending, "pho" committed and pending; `resumeNewest` with ids 1…3 then `resumeNext` with ids 4…6 → cards `[1, 2, 3]`, one `search_performed`, `cancelledRequestCount == 1`.
  - `retypingAtTheDeadlineRequestsOnlyTheLatestQuery` (Review Focus 2): "ph", `waitForSleepers(1)`, `advance(300 ms)`, then "pho" before yielding → after `commit()` the only request is `"pho"`.
  - `clearingRestoresBrowseWithoutARequest` (AC-S4): browse with 40 cards; search loaded; `searchTextChanged(to: "")` → `cards == 1…40`, `listContext == .browse`, request count unchanged; `.searchCleared(queryLength: 5, hadResults: true)`.
  - `clearingDuringTheDebounceSendsNothing` (no request after `advance(300 ms)`; `.searchCleared(queryLength: 2, hadResults: false)`); `clearingDropsAnInFlightSearch` (Review Focus 3).
  - `searchStartedFiresOnceUntilEmpty` ("p" → `.searchStarted(sort: .defaultOrder)`; "ph", "p" → none; "" → `search_cleared`; "q" → second `search_started`).
  - `performedEventCarriesNoQueryText` ("red  shoes" → `queryLength: 10, wordCount: 2`; no `.string` property value contains "red" or "shoes").
  - `noResultsShowsNoResultsState` (AC-S5): empty page → `.noResults(query: "zzz")`, `totalCount: 0`; `clearSearch()` → browse, `.searchCleared(queryLength: 3, hadResults: false)`.
  - `searchFailureShowsErrorAndRetryRecovers`: `.failed(.offline)`, `.searchFailed(trigger: .typing, queryLength: 5, error: .offline)`; `retry()` → `.retryRequested(failedSurface: .search, error: .offline)` then `.searchPerformed(trigger: .retry, …)`; `cancelledSearchSendsNothing`.
  - `browsePageFinishesWhileSearching` (Review Focus 4); `hiddenListIgnoresItemAppeared` (`itemAppeared(id: 20, in: .browse)` while searching → no request).
  - `catalogViewedReportsTheListOnScreen` (`list_context: search` while searching).
- [x] **Step 3:** Run → compile failure, then assertion failures. **Step 4:** Implement (`searchTask`: sleep, `guard !Task.isCancelled`, begin, fetch, finish; begin creates a new search feed stamped with a new generation and cancels the old search page task). **Step 5:** Run → pass.
- [x] **Step 6:** Commit `feat: add debounced catalog search`.

### Task 7: Sort, and search pagination, refresh and teardown

**Files:** Modify `CatalogViewModel.swift`; Test new `MerchantCatalogTests/Features/Catalog/CatalogViewModelSortTests.swift`, `CatalogViewModelSearchTests.swift`.

**Interfaces — Produces:** `func sortSelected(_ sort: ProductSort)` — same value: nothing; otherwise `sort_changed`, then page 1 of the list on screen with trigger `sort_change` (browse via `firstPageTask`, search via `searchTask`, no debounce), cancelling that list's page task and its previous page-1 task.

- [x] **Step 1: Write failing tests:**
  - Sort: `sortChangeReloadsFirstPage` (`.sortChanged(from: .defaultOrder, to: .priceAscending, listContext: .browse)`; phase `.initialLoading` while pending; request `(.priceAscending, 0, 20)`; `.catalogLoadCompleted(trigger: .sortChange, sort: .priceAscending, …)`); `sameSortDoesNothing`; `sortChangeFailureReportsVisibleContent` (`.catalogLoadFailed(trigger: .sortChange, sort: .priceAscending, error: .timeout, hasVisibleContent: true)`); `sortChangeDropsAnInFlightPage` (page 2 pending → sort change → page 2 resumes → no `catalog_page_loaded`, 20 new cards); `latestSortWins` (two quick changes → only the second's result shown; first task cancelled); `sortChangeDuringRefreshWins` (Review Focus 5).
  - Search + sort: `searchUsesTheSortOnScreen` (browse `.ratingDescending` → search request sort `.ratingDescending`); `sortChangeWhileSearchingReloadsSearch` (`listContext: .search`; `.searchPerformed(trigger: .sortChange, …)`); `clearingRestoresTheBrowseSort` (D-46: sort changed in search → clear → `sort == .defaultOrder`, browse cards, no request).
  - Search pages (AC-S3): `searchPaginatesWithQueryAndSort` (`itemAppeared(id: 20, in: .search)` → request `(query: "phone", .priceDescending, 20, 20)`; `.catalogPageRequested(listContext: .search, pageIndex: 2, sort: .priceDescending, isRetry: false)`, `.catalogPageLoaded(listContext: .search, …)`); `newQueryDropsAnInFlightSearchPage`.
  - `refreshWhileSearchingReloadsTheQuery` (`.catalogRefreshed(listContext: .search, outcome: .success, durationMs: 0)`; no `search_performed`).
  - Teardown: `releasingTheViewModelCancelsTheSearch` (pending search → released → `cancelledRequestCount == 1`, no `search_performed`); `releasingTheViewModelDuringTheDebounceSendsNothing`.
- [x] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add server-side sort for browse and search`.

### Task 8: Catalog UI

**Files:** Create `MerchantCatalog/Features/Catalog/Presentation/ProductSort+Title.swift`; Modify `CatalogView.swift`; Test `MerchantCatalogTests/Features/Catalog/ProductSortTitleTests.swift`.

**Interfaces — Produces:** `extension ProductSort: Identifiable { var title: String; var shortTitle: String }` — titles exactly the spec's four; short titles for the toolbar label: "Default", "Lowest price", "Highest price", "Top rated". `CatalogView`: inline title; `.searchable(text:isPresented:placement: .navigationBarDrawer(displayMode: .always), prompt: "Search products")` bound to `searchText` / `searchTextChanged(to:)`; a `.topBarLeading` `Menu` with a `Picker` (label: arrow icon + `shortTitle`, accessibility "Sort, <title>"); a `ZStack` with the browse list (always present; `opacity 0`, no hit testing, accessibility-hidden while searching) and the search list on top when `searchList != nil`; `noResults` → `ContentUnavailableView` with the spec copy and **Clear search** (`clearSearch()` and dismisses the field).

- [x] **Step 1: Write failing test** `titlesMatchTheSpec` (four titles, exact copy).
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run the full suite → pass, `NavigationRuleTests` included. No layout unit tests (no snapshot tests).
- [x] **Step 5:** Commit `feat: add search field and sort menu to the catalog`.

### Task 9: Docs and review gate

**Files:** `docs/ProductSpecification.md` § 4.2 (D-45–D-47, D-50 behavior, no-results state row), `docs/Architecture.md` (§ 2 new files, § 5 debounce/tasks, § 8 feeds), `docs/Networking.md` (§ 2 as built), `docs/ImplementationPlan.md` (D-44–D-52, review log, status), README status line, this plan's checkboxes and deviations.

- [x] **Step 1:** `xcodebuild … clean build` → `** BUILD SUCCEEDED **`; result bundle `warningCount: 0`.
- [x] **Step 2:** `xcodebuild … -configuration Release build` → succeeds, 0 warnings.
- [x] **Step 3:** `xcodebuild … test` → all pass; record counts.
- [x] **Step 4:** Update docs and the review log (manual Simulator checks, limitations, open questions); status `READY_FOR_REVIEW`.
- [x] **Step 5:** Commit `docs: record S3 review gate`.

## Deviations found during implementation

- Task 1: `searchQueryIsPercentEncoded` was seen failing on its assertion (`q=a+b%20%26%20c%3Dd`) before the `%2B` line; the other new tests failed on compilation first.
- Task 4: extra test `sleepCancelledBeforeItStartsThrows`. The suite was also run 50 times in a row (`-test-iterations 50 -run-tests-until-failure`, 200 runs, all passed) to check `TestClock` for races.
- Task 5: an extra row for `search_performed` with `trigger: sort_change` and zero results. `search_failed` has no `http_status`, as Analytics.md defines it.
- Task 6, refactor: `itemAppeared(id:in:)` got its `context == listContext` guard in the refactor commit, before a test needed it. `hiddenListIgnoresItemAppeared` was mutation-checked: its first version still passed with the guard removed (the stray request is recorded only once its task runs), so it now asserts on the synchronous effects (no `catalog_page_requested`, browse footer idle) and fails without the guard.
- Task 6, search: with the `Task.isCancelled` check after the sleep removed, `retypingAtTheDeadlineRequestsOnlyTheLatestQuery` hung instead of failing (the stale request waited on the fake forever). It now queues answers, so it fails (`["ph", "pho"]`), and the search and sort suites have a 1-minute time limit. The no-results case was added to `CatalogView` here, because the phase switch must stay exhaustive. A cancelled search page 1 restores the list's previous first-page status, like browse; for a new query that is "not loaded", which shows the same skeleton.
- Task 7: the search pagination, refresh and teardown tests passed when first run, because Task 6's per-list code already handled them. Each was mutation-checked and failed: page and refresh requests without the query, `deinit` without cancelling `searchTask`, no page-task cancel in `beginFirstPage`, no `firstPageTask` cancel before a browse page 1. `beginSearch`'s own page-task cancel was removed as redundant (`beginFirstPage` cancels it). `releasingTheViewModelDuringTheDebounceSendsNothing` asserts before awaiting, so the mutation fails it instead of hanging.
- Task 8: the sort menu sits at `.topBarLeading`, clear of the centered inline title and the DEBUG Diagnostics button (trailing). A failed search's title reads "Couldn't search products".
