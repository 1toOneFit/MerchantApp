# S5 — Saved Products Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merchants save products from catalog cards and the details toolbar, find them in a Saved tab that survives relaunch and works offline, and reopen them as a snapshot that refreshes from `/products/{id}`, with the Saved analytics events.

**Architecture:** `SavedProduct` snapshots persist through `SavedProductsRepository` (an actor writing a versioned JSON file). `SavedProductsStore` (`@MainActor @Observable`, one instance in the container) is the in-memory source of truth that every surface observes; it returns a `SavedProductsChange` for each save/remove, from which view models build `product_saved` / `product_unsaved`. Details opened from Saved get `ProductDetailRoute.saved(SavedProduct)`, render the snapshot, then fetch `ProductsTarget.detail`. `AnalyticsService` derives `saved_product_revisited` from `product_details_viewed`, which carries the product's `savedAt` (D-64).

**Tech Stack:** Xcode 26.0, Swift 6 language mode (strict concurrency complete, no default isolation), SwiftUI iOS 26.0, Observation, Swift Testing. No packages.

**Spec:** [ImplementationPlan.md § S5](../ImplementationPlan.md#s5--saved-products), [ProductSpecification.md § 4.3, § 4.4](../ProductSpecification.md#44-saved-products), [Analytics.md § 2, § 3 Saved/Details](../Analytics.md), [Networking.md A6, A7, § 2](../Networking.md), [Architecture.md § 4–7, § 9](../Architecture.md). Builds on [S4](S4-product-details.md).

## Global Constraints

- Neutral naming only (`MerchantCatalog`). No third-party dependencies. No caching (D-10): snapshots are user data.
- File I/O never on the main actor (ProductSpecification § 7): the repository is an actor.
- Swift Testing, `@Suite(.timeLimit(.minutes(1)))` on view-model suites; no live network or real Application Support in tests.
- Analytics code and Analytics.md change in the same commit; `TaxonomyDocumentationTests` stays green.
- Copy (verbatim): "Couldn't refresh — showing saved info", "Price changed since you saved it", "This product is no longer available." (`AppError.notFound.userMessage`), "Price when saved: $9.99", "Saved 3 Nov", "Browse catalog".
- Developer decisions (2026-11-13): D-60 card save button = sibling overlay on the thumbnail's top-trailing corner; D-61 `TabSelection` observable owned by `AppTabView`, injected like the router; D-62 `ProductDetailRoute` enum `.list` / `.saved`; D-63 `product_details_viewed` from Saved at first appearance with `content_origin: snapshot`, `network` removed; D-64 `saved_product_revisited` derived inside `AnalyticsService`; D-65 bad JSON quarantined, unknown version left in place (start empty, `.error` log).

## Review Focus

1. Fast save → unsave → save: unordered writes would leave a stale file. Writes are chained; `writesHappenInOrder` (Task 2).
2. A save before the launch load finishes must not be lost or overwrite the file. `changesBeforeLoadAreKept` (Task 2).
3. Leaving details while the refresh is in flight: no failure banner, no `product_details_load_failed`. `cancelledRefreshChangesNothing` (Task 7).
4. Unsave on details opened from Saved, then save again while only the snapshot is known: same snapshot fields, new `savedAt`. `resavingFromTheSnapshotKeepsItsFields` (Task 7).
5. Decimal prices survive the file exactly (9.99, 1899.99). `roundTripKeepsItemsOrderAndPrices` (Task 1).

---

### Task 1: Saved snapshot and file repository

**Files:** Create `MerchantCatalog/Shared/Saved/Domain/{SavedProduct, SavedProductsRepository}.swift`, `MerchantCatalog/Shared/Saved/Data/FileSavedProductsRepository.swift`; Test `MerchantCatalogTests/Shared/Saved/{SavedProductTests, FileSavedProductsRepositoryTests}.swift`, `MerchantCatalogTests/Support/TemporaryDirectory.swift`.

**Interfaces — Produces:**
- `struct SavedProduct: Identifiable, Hashable, Sendable { id: Int; title: String; thumbnailURL: URL?; price: Decimal; rating: Double?; category: String?; savedAt: Date }` + memberwise init; `init(_ product: Product, savedAt: Date)`; `var displayProduct: Product` (id, title, price, thumbnail, category, rating; no images, everything else absent).
- `protocol SavedProductsRepository: Sendable { func load() async -> [SavedProduct]; func save(_ items: [SavedProduct]) async }` — never throws: failures are logged (`persistence`) and give `[]` / leave the file.
- `actor FileSavedProductsRepository: SavedProductsRepository { init(directory: URL, now: @escaping @Sendable () -> Date = Date.init); static let fileName = "saved-products.json" }`. Format `{ "version": 1, "items": [{ id, title, thumbnailURL?, price: "9.99", rating?, category?, savedAt: ISO 8601 with milliseconds }] }`; atomic write, creates the directory. Bad JSON → renamed `saved-products.corrupt-<yyyyMMdd'T'HHmmss'Z'>.json` (UTC) + `.error` log → `[]`. `version != 1` → `.error` log, file untouched, `[]` (D-65).

- [x] **Step 1: Failing tests.** `SavedProductTests`: `snapshotKeepsTheSpecFields`, `displayProductCarriesOnlySnapshotFields`. Repository (each test its own `TemporaryDirectory`, `now` = 2026-11-13T10:00:00Z): `missingFileLoadsEmpty`; `roundTripKeepsItemsOrderAndPrices` (prices 9.99 and 1899.99, `savedAt` with ms, nil rating/category/thumbnail); `writesTheVersionedEnvelope` (raw JSON: `version == 1`, `price == "9.99"`); `saveReplacesPreviousContents`; `saveCreatesTheDirectory`; `corruptFileIsQuarantined` (loads `[]`, original gone, `saved-products.corrupt-20261113T100000Z.json` holds the old bytes); `unsupportedVersionIsLeftInPlace` (loads `[]`, bytes unchanged, no corrupt file).
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: persist saved product snapshots`.

### Task 2: Saved products store

**Files:** Create `MerchantCatalog/Shared/Saved/SavedProductsStore.swift`; Modify `Core/Analytics/UserProperty.swift` (`.savedProductsCount(Int)` → `saved_products_count`, `.int`); Test `MerchantCatalogTests/Shared/Saved/SavedProductsStoreTests.swift`, `MerchantCatalogTests/Fakes/InMemorySavedRepository.swift`.

**Interfaces — Produces:**
- `enum SavedProductsChange: Equatable { case saved(SavedProduct, countAfter: Int); case removed(SavedProduct, savedDurationS: Int, countAfter: Int) }`.
- `@MainActor @Observable final class SavedProductsStore { init(repository: any SavedProductsRepository, analytics: any AnalyticsTracking, now: @escaping () -> Date = Date.init); private(set) var items: [SavedProduct] /* newest first */; private(set) var isLoaded: Bool; var count: Int; func load() async /* once */; func isSaved(_ id: Product.ID) -> Bool; func item(id: Product.ID) -> SavedProduct?; @discardableResult func save(_ product: Product) -> SavedProductsChange? /* nil if saved */; @discardableResult func remove(id: Product.ID) -> SavedProductsChange? /* nil if not saved */; @ObservationIgnored private(set) var writeTask: Task<Void, Never>? }`.
- `saved_duration_s` = whole seconds `now − savedAt`, clock moved back → 0. Writes: each change after the load chains a task awaiting the previous one, then `repository.save(items)` (unstructured: started from a tap; the handle keeps order). Changes before the load finishes stay in memory; the load merges them over the stored list (ids touched before the load win) and writes once. `saved_products_count` is set after the load and after every change.

- [x] **Step 1: Failing tests:** `loadsNewestFirstAndSetsCount` (`userProperties == [.savedProductsCount(2)]`); `loadRunsOnce`; `saveReturnsTheChangeAndPersists` (`.saved(SavedProduct(product(4), savedAt: now), countAfter: 1)`, after `await writeTask?.value` the fake's last write is `[that]`); `savingASavedProductIsIgnored`; `removeReportsTheSavedDuration` (saved 10:00:00, removed 10:01:30.9 → `savedDurationS: 90, countAfter: 0`); `clockMovedBackGivesZeroDuration`; `removingAnUnsavedProductIsIgnored`; `countPropertyFollowsChanges`; `writesHappenInOrder` (save, remove, save → last write has one item); `changesBeforeLoadAreKept` (load suspended; save 1, remove 3; load answers [2, 3] → items [1, 2], one write [1, 2]).
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add the saved products store`.

### Task 3: Single-product endpoint

**Files:** Modify `Shared/Products/Data/{ProductsTarget, LiveProductRepository}.swift`, `Shared/Products/Domain/ProductRepository.swift`, `MerchantCatalogTests/Fakes/FakeProductRepository.swift`; Test `ProductsTargetTests`, `LiveProductRepositoryTests`.

**Interfaces — Produces:** `ProductsTarget.detail(id: Int)` → `/products/<id>`, no query items. `ProductRepository.product(id: Product.ID) async throws -> Product` (`@concurrent` in `LiveProductRepository`). Fake: `productRequests: [Int]`, `enqueueProduct(_: Result<Product, any Error>)`, `resumeNextProduct(with:)`, `waitForPendingProductRequests(_:)`, unanswered requests suspend (as pages do).

- [x] **Step 1: Failing tests:** `detailPathHasNoQuery`; `requestsDetailTargetAndMapsProduct`; `detailPropagatesNotFound`.
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add the product detail endpoint`.

### Task 4: Saved analytics events and revisit derivation

**Files:** Modify `Core/Analytics/{AnalyticsEvent, AnalyticsValue, AnalyticsService}.swift`, callers of the changed cases (`CatalogViewModel`, `ProductDetailViewModel`), `docs/Analytics.md`; Test new `MerchantCatalogTests/Core/Analytics/SavedAnalyticsEventTests.swift`, `DetailsAnalyticsEventTests`, `AnalyticsEventTests`, `AnalyticsServiceTests`, call sites in existing suites.

**Interfaces — Produces:**
- `AnalyticsValue.double(Double)` (description `String(value)`); `ProductSource.saved`; `ContentOrigin.snapshot`; `FailedSurface.details`; `enum SaveSurface: String { catalogCard = "catalog_card", searchCard = "search_card", details, savedList = "saved_list" }`.
- `.productSelected(productID:source:position:sort: ProductSort?)` — `sort` omitted when nil.
- `.productDetailsViewed(productID:source:category:availability:hasDiscount: Bool?, imageCount: Int?, savedAt: Date?, contentOrigin:)` — sends `is_saved = savedAt != nil`, never the date; nil `has_discount` / `image_count` omitted.
- `.productDetailsLoadFailed(productID:source:error:showingSnapshot:)`; `.productSaved(productID:surface:category: String?, price: Decimal, position: Int?, savedCountAfter:)` (`price` sent as `.double`); `.productUnsaved(productID:surface:savedDurationS:savedCountAfter:)`; `.savedProductsViewed(savedCount:)`; `.savedProductRevisited(productID:source:daysSinceSaved:)`.
- `extension SavedProductsChange { func event(surface: SaveSurface, position: Int?) -> AnalyticsEvent }` (in `SavedProductsStore.swift`).
- `AnalyticsService.track`: after delivering `.productDetailsViewed` with `savedAt < session.startedAt` and the id not yet revisited in this session id, delivers `.savedProductRevisited` with `daysSinceSaved` = whole 24 h periods (≥ 0).
- Analytics.md: five events Active; `is_saved` live (D-56 closed); `content_origin` `list` | `snapshot` (D-63); `has_discount`/`image_count` omitted for `snapshot`; `product_selected` `sort` omitted for `saved`; `saved_product_revisited` derived by `AnalyticsService` (D-64), `days_since_saved` definition.

- [x] **Step 1: Failing tests:** exact dictionaries for each new/changed case (`price: 9.99` → `.double(9.99)`; nil category/position omitted; `is_saved: true` without a date key); `.double(9.99).description == "9.99"`. Service: `revisitFollowsDetailsOfAProductSavedBeforeTheSession` (saved 2026-11-10T11:00Z, now 2026-11-13T10:00Z → `days_since_saved: 2`, delivered right after the view); `noRevisitForAProductSavedThisSession`; `noRevisitForAnUnsavedProduct`; `revisitOncePerProductPerSession`; `aNewSessionRevisitsAgain`.
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement code + Analytics.md. **Step 4:** Run → pass (taxonomy test included).
- [x] **Step 5:** Commit `feat: add saved products analytics events`.

### Task 5: Saved route and tab selection

**Files:** Modify `Core/Navigation/{ProductDetailRoute, Route}.swift`; move `App/AppTab.swift` → `Core/Navigation/AppTab.swift`; Create `Core/Navigation/TabSelection.swift`; adapt `CatalogViewModel.cardSelected`, `ProductDetailViewModel`, `AppTabView` (selection bound to `TabSelection`); Test `RouterTests`, new `TabSelectionTests`, `CatalogViewModelSelectionTests`, `ProductDetailViewModelTests`.

**Interfaces — Produces:** `enum ProductDetailRoute: Hashable { case list(Product, source: ProductSource); case saved(SavedProduct); var productID: Product.ID; var source: ProductSource /* saved → .saved */ }`. `@MainActor @Observable final class TabSelection { var selected: AppTab; init(selected: AppTab = .catalog); func select(_ tab: AppTab) }`.

- [x] **Step 1: Failing tests:** `routeExposesIDAndSource` (both cases); `TabSelectionTests.startsOnCatalog`, `selectSwitchesTab`; existing tests rewritten to `.list(product, source:)`.
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add the saved details route and tab selection`.

### Task 6: Save from catalog cards

**Files:** Modify `Features/Catalog/Presentation/{CatalogViewModel, CatalogConfigurator, CatalogView}.swift`; Create `DesignSystem/Components/SaveButton.swift`; Test new `MerchantCatalogTests/Features/Catalog/CatalogViewModelSaveTests.swift`, `savedProducts:` at the other catalog suites' call sites.

**Interfaces — Produces:** `CatalogViewModel.init(repository:analytics:router:savedProducts: SavedProductsStore, clock:)`; `func isSaved(_ id: Product.ID) -> Bool`; `func saveToggled(id: Product.ID, in context: ListContext)` — hidden list / unknown id ignored; surface `.catalogCard` / `.searchCard`, `position` = index in that list. `SaveButton(isSaved: Bool, action:)`: `bookmark` / `bookmark.fill`, labels "Save" / "Remove from Saved", ≥ 44 pt. Card = `ZStack(alignment: .topTrailing) { card Button; SaveButton }` (D-60).

- [x] **Step 1: Failing tests:** `savingABrowseCardTracksAndUpdatesTheStore` (id 4 → `.productSaved(productID: 4, surface: .catalogCard, category: nil, price: 4.99, position: 3, savedCountAfter: 1)`, `isSaved(4)`); `unsavingACardTracksTheDuration`; `searchCardUsesTheSearchSurfaceAndPosition`; `hiddenListSaveIsIgnored`; `unknownCardSaveIsIgnored`; `isSavedFollowsChangesFromElsewhere`.
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement (UI included). **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: save products from catalog cards`.

### Task 7: Details: save toggle, snapshot and refresh

**Files:** Modify `Features/ProductDetail/Presentation/{ProductDetailViewModel, ProductDetailConfigurator, ProductDetailView}.swift`; Test `ProductDetailViewModelTests`, new `ProductDetailSavedTests.swift`, `AppContextRegistrationTests`.

**Interfaces — Produces:**
- `ProductDetailViewModel.init(route:repository: any ProductRepository, savedProducts: SavedProductsStore, analytics:)`; `private(set) var product: Product` (list product, `snapshot.displayProduct`, or the fresh product); `header`, `insights`, `gallery` computed from it; `private(set) var refresh: DetailRefreshState` (`enum { idle, loading, refreshed, failed(AppError), unavailable }`); `var isShowingSnapshot: Bool`; `var savedSnapshot: SavedProduct?` (route's); `var savedPriceIfChanged: Decimal?` (snapshot price after a refresh with a different price); `var isSaved: Bool`; `func start() async` (Saved route only, while `idle`; cancellation → back to `idle`); `func retry()` (only from `failed`: `retry_requested` `details`, then an owned task, cancelled by `isolated deinit`); `func saveToggled()` (surface `.details`, no position; saves the product on screen).
- Events: `product_details_viewed` with `savedAt: savedProducts.item(id:)?.savedAt`; Saved route → `.snapshot`, `hasDiscount`/`imageCount` nil. A failed fetch → `.productDetailsLoadFailed(productID:source: .saved, error:, showingSnapshot: isShowingSnapshot)`; 404 → `unavailable` (no Retry). The store's snapshot is never overwritten by fresh data.
- View: toolbar `SaveButton`; under the header: snapshot note "Saved information · Saved 3 Nov" while showing the snapshot, "Updating…" while loading, the refresh banner + Retry on failure, the 404 notice; in Pricing, "Price changed since you saved it" + "Price when saved: …". `.task { await viewModel.start() }`.

- [x] **Step 1: Failing tests:** `detailsViewedReportsTheSavedDate`; `toolbarSaveAndUnsaveTrackDetailsSurface`; `savedRouteShowsTheSnapshotFirst` (no request before `start()`); `savedRouteViewedEventUsesTheSnapshot`; `refreshReplacesTheSnapshot` (`/products/1` once, `refreshed`, no price note when equal); `priceChangeIsReported` (9.99 → 12.49 gives 9.99); `refreshFailureKeepsTheSnapshot` (`.failed(.offline)` + event); `retryTracksAndRefetches`; `notFoundShowsUnavailable` (event `not_found`, `retry()` ignored); `cancelledRefreshChangesNothing` (cancelled → `idle`, no event; `start()` again fetches); `startFetchesOnce`; `listRouteNeverFetches`; `snapshotIsNotOverwritten`; `resavingFromTheSnapshotKeepsItsFields`; `saveOnDetailsUpdatesTheCatalogCard` (AC-D3: one store, `CatalogViewModel.isSaved`). Registration: `productDetailDependenciesResolve` with the new services.
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement (UI included). **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: save and refresh products on the details screen`.

### Task 8: Saved tab

**Files:** Create `Features/Saved/Presentation/{SavedRowModel, SavedViewModel, SavedView, SavedConfigurator}.swift`; Modify `App/{AppContext, AppTabView, MerchantCatalogApp}.swift`; Test new `MerchantCatalogTests/Features/Saved/{SavedRowModelTests, SavedViewModelTests}.swift`, `AppContextRegistrationTests`.

**Interfaces — Produces:**
- `SavedRowModel(_ item: SavedProduct, locale: Locale = .current, timeZone: TimeZone = .current)`: `id`, `title`, `thumbnailURL`, `priceWhenSaved` ("Price when saved: $9.99"), `savedDate` ("Saved 13 Nov" in en_GB).
- `SavedViewModel.init(savedProducts:analytics:router:tabs: TabSelection)`; `phase` (`loading` until the store loaded, `empty`, `content`); `rows`; `savedBecameVisible()` → `.savedProductsViewed(savedCount:)`; `rowSelected(id:)` → `.productSelected(source: .saved, position:, sort: nil)` + `.saved(snapshot)` pushed; `removeSwiped(id:)` → `.productUnsaved(surface: .savedList, …)`; `browseCatalogTapped()` → `tabs.select(.catalog)`.
- `SavedConfigurator.make(from:router:tabs:isTabSelected:) -> SavedView` + `resolveDependencies(from:)`. `AppContext.configure(…, savedProductsDirectory: URL = .applicationSupportDirectory)` registers `SavedProductsStore` and exposes `savedProducts`; `MerchantCatalogApp` runs `.task { await context.savedProducts.load() }` and passes the store to `AppTabView` for `.badge(count)`.

- [x] **Step 1: Failing tests:** `rowShowsSavedInformation`; `rowsFollowTheStoreNewestFirst`; `phaseFollowsTheStore`; `viewedEventCountsSavedProducts`; `rowTapTracksAndPushesTheSavedRoute`; `swipeRemovesAndTracks`; `swipeUpdatesTheCatalogCard` (AC-V4); `browseCatalogSwitchesToTheCatalogTab`; `savedDependenciesResolve`; `savedStoreIsShared` (`context.savedProducts === container.resolve()`).
- [x] **Step 2:** Run → compile failure. **Step 3:** Implement (UI included). **Step 4:** Run → pass, `NavigationRuleTests` included.
- [x] **Step 5:** Commit `feat: add the saved products tab`.

### Task 9: Docs and review gate

**Files:** `docs/ProductSpecification.md` (§ 4.3/4.4 as built), `docs/Architecture.md` (§ 2, 6, 7, 9 as built), `docs/Networking.md` (§ 2 `.detail` built), `docs/ImplementationPlan.md` (decisions, review log, status), README status line, AILog (D-64 developer choice), this plan.

- [x] **Step 1:** `xcodebuild … clean build` → `** BUILD SUCCEEDED **`, result bundle `warningCount: 0`; Release build 0 warnings; test-action log without compiler warnings.
- [x] **Step 2:** `xcodebuild … test` → all pass; record counts.
- [x] **Step 3:** Review log with manual Simulator checks (save from a card and from details, all surfaces; terminate and relaunch; Saved tab offline; details from Saved offline, 404 not reachable from the UI; swipe to remove; badge; Browse catalog). Status `READY_FOR_REVIEW`.
- [x] **Step 4:** Commit `docs: record S5 review gate`.

## Deviations found during implementation

- Task 1: extra test `undecodableItemsAreQuarantined` (valid JSON whose items don't decode counts as corrupt).
- Task 2: `changesBeforeLoadAreKept` first also removed a stored product before the load finished. That can't happen (an item the store hasn't read isn't shown as saved), so the case was replaced by a pre-load save of an id that is also stored: the newer snapshot wins. The store sorts the merged list by `savedAt`. Extra test `newSavesGoFirst`. `writesHappenInOrder` and `changesBeforeLoadAreKept` passed when first run after compiling; both were mutation-checked (without the write chain the writes land as `[[], [2], [1]]`; without the merge filter the count is 4).
- Task 2: the Analytics.md note on `saved_products_count` changed in this commit, with the user property.
- Task 4: `price` is converted through the decimal's string (`Decimal.analyticsValue`): `NSDecimalNumber.doubleValue` turned 1899.99 into 1899.9900000000002, which the event test caught. Extra tests `savedChangeBecomesProductSaved`, `removedChangeBecomesProductUnsaved`. The revisit dedup and its per-session reset were mutation-checked.
- Task 6: `AppContext` registers `SavedProductsStore` here, not in Task 8, because `CatalogConfigurator`'s registration guard needs it. The card uses `CardSaveButton` (a 32 pt circle on a material inside a 44 pt target); `SaveButton` is the toolbar variant. The hidden-list guard was mutation-checked.
- Task 7: `SavedProductFormat` ("Price when saved: …", "Saved 3 Nov") was added test-first for the details note and the Saved rows. Extra tests `refreshIsLoadingWhileInFlight`, `failedRetryReportsAgain`, `leavingTheScreenCancelsTheRetry`. `header`, `insights` and `gallery` are computed from `product`, which the refresh replaces. The `isolated deinit` cancel and the 404 branch were mutation-checked.
- Task 8: extra test `unknownRowIsIgnored`. The Saved tab shows nothing until the store has read the file (`SavedPhase.loading`), so the empty state never flashes at launch.
