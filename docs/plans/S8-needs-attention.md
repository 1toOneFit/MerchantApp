# S8 — Needs attention: Implementation Plan

> **For agentic workers:** executed inline by the agent (superpowers:executing-plans), task by task, TDD. Steps use checkbox (`- [ ]`) syntax.

**Goal:** answer "Which products need my attention?" within seconds: stock status on every card, a "Needs attention" scope over the loaded catalog, stock up front on details, and a deterministic XCUITest suite.

**Architecture:** one domain policy (`StockStatus(stock:)`) feeds cards, the attention scope, details and the `availability` analytics property. The attention scope is a filter of the list on screen inside `CatalogViewModel` (no new request, no new pipeline). UI tests launch the app with `-ui-testing`, which (DEBUG only) swaps the registered `ProductRepository` for an in-memory fixture through `AppContext.configure(productRepository:)`.

**Tech stack:** Swift 6, SwiftUI, iOS 26.0, Xcode 26.0, Swift Testing (unit), XCTest/XCUITest (UI). No packages.

**Spec:** the developer's S8 request (2026-11-14), recorded in [ImplementationPlan.md § S8](../ImplementationPlan.md#s8--needs-attention); decisions D-84–D-89.

## Global constraints

- Neutral naming (`MerchantCatalog`); no caching; no third-party dependencies; Swift 6 strict concurrency, zero warnings.
- Status policy, verbatim: `stock == 0` → Out of stock; `stock in 1...10` → Low stock; `stock > 10` → In stock. One place, unit-tested.
- No basket, checkout, editing, ordering, restocking, notifications, inventory dashboard or new tabs.
- Needs attention uses only loaded products; the limitation is stated in the UI ("Based on …") and docs.
- Fixture code compiles only in DEBUG and only runs with `-ui-testing`; Release and normal launches are unchanged.
- The agent never drives the Simulator by hand; UI tests run only through `xcodebuild test`.

## Review focus

1. Attention scope + auto-pagination: a card near the end of the *filtered* list must not page (the loaded list's end is elsewhere) → `attentionScopeDoesNotPageOnAppear`.
2. Attention scope while searching: filters the search results, not browse → `attentionScopeFiltersSearchResults`.
3. A summary with unknown stock (`stock` missing) shows no indicator and never counts as needing attention → `unknownStockHasNoStatus`, `cardWithoutStockHasNoLabel`.
4. A saved snapshot must not show stale stock offline → `savingDropsStock`.
5. `-ui-testing` absent → the live repository is registered → `liveRepositoryWithoutOverride`.

---

### Task 1: Stock status policy, decoding and list select (D-84)

**Files:** create `Shared/Products/Domain/StockStatus.swift`; modify `Product.swift` (drop stored `availability` + `ProductAvailability`, add `var stockStatus: StockStatus?`), `ProductSummary.swift` (add `stock: Int?`, explicit init with `stock: Int? = nil`; `Product.summary` passes it; `displayProduct` passes `stock: nil`), `ProductDTO.swift` (`ProductSummaryDTO.stock`; stop decoding `availabilityStatus`), `ProductsTarget.swift` (`select=title,price,thumbnail,rating,category,stock`), `AnalyticsEvent.swift` (`availability: StockStatus?`), `ProductDetailViewModel.swift` (`availability: shown.stockStatus`, placeholder without `availability`). Tests: new `Shared/Products/StockStatusTests.swift`; update `ProductsTargetTests`, `ProductDTOTests`, `ProductFixtures` (`makeProduct(availability:)` → stock), callers.

**Produces:** `enum StockStatus: Hashable, Sendable { case outOfStock, lowStock, inStock }`, `static let lowStockLimit = 10`, `init?(stock: Int?)`, `var needsAttention: Bool`, `var analyticsValue: String`; `ProductSummary.stock: Int?`; `Product.stockStatus`.

- [ ] Tests: `policy` parameterized `(nil→nil, -1→.outOfStock, 0→.outOfStock, 1→.lowStock, 10→.lowStock, 11→.inStock, 99→.inStock)`; `unknownStockHasNoStatus`; `needsAttention` (out, low true; in false); `selectIncludesStock` (target pins the select string); `summaryDecodesStock`; `statusComesFromStockNotAvailabilityStatus` (`"availabilityStatus":"In Stock","stock":7` → `.lowStock`).
- [ ] Run → compile failure (no `StockStatus`). Implement. Run all unit tests → green. Analytics.md (`availability` source) in the same commit.

### Task 2: Stock on cards and in the card's VoiceOver label (D-86)

**Files:** create `DesignSystem/Components/StockLabel.swift` (`struct StockLabel: Hashable { status; text; accessibilityText; init?(stock: Int?) }` + `StockStatusView` badge/row view); modify `ProductCardModel` (`stock: StockLabel?`), `ProductCardView` (row under the price, hidden placeholder of equal height when unknown), `ProductCardAccessibility.label(… stock: String? …)`, `CatalogView` call site. Tests: new `StockLabelTests`; `ProductCardModelTests`, `ProductCardAccessibilityTests`.

- [ ] Tests: texts `"Out of stock"`, `"Low stock · 7 left"`, `"In stock"`; accessibility `"Low stock, 7 left"`; `cardCarriesStockLabel`; `cardWithoutStockHasNoLabel`; label `"Lamp, $9.99, low stock, 4 left, not saved"` (stock after price, before rating).
- [ ] Red → implement → green → commit.

### Task 3: Needs-attention scope in the catalog (D-85)

**Files:** create `Features/Catalog/Presentation/CatalogScope.swift` (`enum CatalogScope { case all, needsAttention }`, `struct AttentionCoverage: Equatable { loaded: Int; total: Int; isComplete: Bool }`); modify `CatalogFeed` (`content(scope:)`, `attentionCount`), `CatalogPhase.swift` (`CatalogListContent` gains `scope`, `attentionCount: Int`, `coverage: AttentionCoverage`), `CatalogViewModel` (`scope`, `scopeSelected(_:)`, `attentionCount: Int?`, `loadMoreTapped()`, no auto-paging in attention scope), `CatalogCopy` (`attentionCoverage(_:)`, `noAttention`), `CatalogView` + new `CatalogScopeBar.swift` (chips `catalog.allProducts` / `catalog.needsAttention`, attention empty message, attention footer with "Load more products"). Tests: new `CatalogViewModelAttentionTests`, `CatalogCopyTests`.

- [ ] Tests: `attentionCountCountsLowAndOutOfStock` (nil before content); `needsAttentionShowsOnlyAttentionCardsInServerOrder`; `countUpdatesWhenAPageLoads`; `attentionScopeDoesNotPageOnAppear`; `loadMoreTappedRequestsNextPage` (once, single-flight, none past the end); `attentionScopeFiltersSearchResults`; `coverageReportsLoadedOfTotal`; `selectingTheSameScopeIsANoOp`; copy `"Based on 20 of 194 products loaded so far."` / `"Based on all 194 products."`.
- [ ] Red → implement → green → commit.

### Task 4: Details lead with title, price, stock, category, rating (D-87)

**Files:** modify `ProductDetailHeader` (`price: String`, `stock: StockLabel?`, `rating: String?`), `ProductInsights` (At a Glance without rating/availability; Pricing without price; Shipping & availability: `.availability(StockStatus)` from stock, then `.stock(n)`), `ProductFactRow`, `ProductDetailView` (header layout, identifiers `productDetail.title`, `.price`, `.stockStatus`, `.saveButton`; Pricing shown when it has a fact or the price-changed note). Tests: `ProductDetailHeaderTests`, `ProductInsightsTests`, `ProductFactRowTests`, details view-model analytics expectations.

- [ ] Tests: header `price == "$9.99"`, `stock?.text == "Low stock · 4 left"`, `rating == "4.94"`; snapshot header has no stock; insights groups per above; fact row `("Availability", "Low stock")`.
- [ ] Red → implement → green → commit.

### Task 5: Saved snapshots keep no stock (D-89)

**Files:** `SavedProductsStore.save(_:)`; test `SavedProductsStoreTests.savingDropsStock`. File format unchanged.

### Task 6: UI-test fixture path and XCUITest target (D-88)

**Files:** create `App/UITesting/UITestLaunch.swift` and `App/UITesting/FixtureProductRepository.swift` (`#if DEBUG`); modify `AppContext.configure(… productRepository: (any ProductRepository)? = nil)`, `MerchantCatalogApp.init`, `SavedView` (`saved.row.<id>`), `CatalogView` (`catalog.productCard.<id>`); project: target `MerchantCatalogUITests` (`com.apple.product-type.bundle.ui-testing`, `TEST_TARGET_NAME = MerchantCatalog`, bundle id `com.example.MerchantCatalogUITests`, Swift 6, complete concurrency), synchronized folder `MerchantCatalogUITests/`, scheme testable. Tests: unit `UITestLaunchTests`, `AppContextRegistrationTests`; UI `MerchantCatalogUITests/CatalogUITests.swift`.

**Fixture:** id 1 "Desk Lamp" stock 42 (in), 2 "Notebook Set" stock 4 (low), 3 "Travel Mug" stock 0 (out), 4 "Wireless Mouse" stock 15 (in); no thumbnails or images (no network); search = case-insensitive title contains; sort applied like the server.

- [ ] Unit tests: `detectsArgument`, `fixtureHasEveryStatus`, `fixtureSearchMatchesTitle`, `unknownIDIsNotFound`, `liveRepositoryWithoutOverride`, `overrideRepositoryIsRegistered`.
- [ ] UI tests: `testLaunchShowsCatalogAndNeedsAttention`, `testNeedsAttentionShowsOnlyLowAndOutOfStock`, `testProductDetailShowsTitleAndStock`, `testSearchFiltersCatalog`, `testSaveFromDetailsShowsInSaved`.
- [ ] Run the UI tests through `xcodebuild test` and see them pass; mutation check: break the attention filter → the attention UI test fails.

### Task 7: Docs and gate

README section (why, policy, no inventory/ordering, fixtures, next step); ProductSpecification § 4.1/4.3/8 + new § 4.6; Architecture § 2/§ 11; Experiments.md (stock row in both arms); Analytics.md; Networking.md A16; CLAUDE.md commands; AILog; review log. Clean build (Debug + Release, 0 warnings), full `xcodebuild test`, `git diff --check`.

## Deviations

*(Filled in during execution.)*
