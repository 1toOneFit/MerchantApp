# S4 — Product Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A card tap in browse or search results opens a product details screen that renders at once from the list's product, as organized facts (gallery, header, At a Glance, Pricing, Overview, Product information, Shipping & availability, Recent reviews), with `product_selected`, `product_details_viewed` and `product_gallery_interacted`.

**Architecture:** `Product` gains the details fields (D-37's follow-up). A pure `ProductInsights` (Domain) turns a product into per-section facts and leaves out every fact the data lacks; empty sections are omitted (AC-D2). `CatalogViewModel` receives the Catalog tab's `Router` by injection (D-53): a card tap tracks `product_selected` from the list on screen and pushes `Route.productDetail(ProductDetailRoute)`. `AppTabView`'s single `navigationDestination` builds `ProductDetailView` through `ProductDetailConfigurator`; the screen owns a `ProductDetailViewModel` that sends the two details events once per push / visit. No request is made: list items carry the full product (Networking.md A7).

**Tech Stack:** Xcode 26.0, Swift 6.2 compiler in Swift 6 language mode, SwiftUI (iOS 26.0), Observation, Swift Testing. No packages.

**Spec:** [ImplementationPlan.md § S4](../ImplementationPlan.md#s4--product-details), [ProductSpecification.md § 4.3, AC-C6](../ProductSpecification.md#43-product-details), [Analytics.md § 3 Details, `product_selected`](../Analytics.md#details), [Networking.md A6, A7, A10, A14, § 4](../Networking.md), [Architecture.md § 7, § 8](../Architecture.md). Builds on [S3](S3-search-sort.md).

## Global Constraints

- Neutral naming only (`MerchantCatalog`). No third-party dependencies. No caching (D-10).
- `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation (D-31). Verified on this branch with `-showBuildSettings` (2026-11-13).
- Insight rule: only facts present in the data; no invented score, margin, recommendation or claim. No computed discounted price (D-11). Reviewer email is never decoded, displayed or logged.
- Section titles, exact copy: **At a Glance**, **Pricing**, **Overview**, **Product information**, **Shipping & availability**, **Recent reviews**.
- `NavigationStack` / `navigationDestination` only in `App/AppTabView.swift`, no `NavigationLink` (`NavigationRuleTests`); `AppTabView` owns no feature view model.
- Analytics code and `docs/Analytics.md` change in the same commit.
- Images: `ProductImageView` per gallery page (visibility-gated `AsyncImage`, D-23).
- Verify with `xcodebuild build` (0 warnings in the result bundle; Release too) and `xcodebuild test` on `platform=iOS Simulator,name=iPhone 17,OS=26.0`. Never launch or drive the app in the Simulator.

## Decisions taken in this plan

| ID | Decision | By | Why |
|---|---|---|---|
| D-53 | The Catalog screen gets its tab's `Router` by injection: `CatalogConfigurator.make(from:router:isTabSelected:)` passes `AppTabView`'s `catalogRouter` to `CatalogViewModel`'s initializer; a card tap calls `cardSelected(id:in:)` | Developer (scope) | Agent recommendation, chosen over a closure callback or a routing protocol. `AppTabView` still owns no view model; tests use a real `Router` and read `path`. |
| D-54 | `searchDismissed()` is ignored while a route is on the Catalog stack | Developer (scope) | Agent recommendation (AC-C6). If SwiftUI deactivates the search field when details are pushed, the S3 Cancel handling would otherwise clear the search. Whether it happens is checked manually. |
| D-55 | The At a Glance rating chip shows the rating only; the 3 reviews appear only under "Recent reviews" | Developer (scope) | Agent recommendation. The aggregate rating isn't based on the 3 returned reviews (ProductSpecification § 6); "rating · 3 reviews" would suggest it is. |
| D-56 | `product_details_viewed` sends no `is_saved` until S5 | Developer (scope) | Agent recommendation, chosen over a constant `false`. S5 adds it with the saved store. |
| D-57 | `ProductDetailRoute` = the list's `Product` + `source`; `Product` becomes `Hashable`. No `ProductsTarget.detail`, no details Retry and no `FailedSurface.details` in S4 | Agent | Details opened from a list need no request (A7); the fetch, its Retry and the saved snapshot arrive with S5, which extends the route. |
| D-58 | Numbers are shown as the API gives them: rating and discount with up to 2 fraction digits ("4.94", "−7.17%"), weight and dimensions without units | Agent | The API gives no units (A14). Rounding the discount to whole percent would show "−0%" for 0.04 %. |
| D-59 | `product_details_viewed` fires at the details view's first appearance, once per view model (one per push); `product_gallery_interacted` at the first page change away from the shown image, once per view model. `category` = the API slug; `availability` omitted when unknown | Agent | Tab switches and re-appearances don't re-send; a new push builds a new view model. |

## Review Focus

1. **A sparse product** (no brand, discount 0, blank warranty, no tags, no reviews, no images) → no empty section or row → Task 2 `sparseProductKeepsOnlyCoreFacts`.
2. **A tap on a card of the hidden browse layer** while search results are shown → nothing tracked, nothing pushed → Task 6 `hiddenListCardIsIgnored`.
3. **Back from details with an active search** → the search, its results and sort are kept even if the field reported a dismissal → Task 6 `searchSurvivesDismissalWhileDetailsArePushed`.
4. **A review with a malformed date or missing fields** → the page still decodes; the email is never mapped → Task 1 `reviewsMapWithoutEmail`, `malformedReviewFieldsAreNil`.
5. **A card tapped after page 2 loaded** → `position` is its index in the list on screen → Task 6 `positionCountsLoadedPages`.

---

### Task 1: Product details fields

**Files:** Modify `MerchantCatalog/Shared/Products/Domain/Product.swift`, `MerchantCatalog/Shared/Products/Data/ProductDTO.swift`, `MerchantCatalogTests/Fakes/ProductFixtures.swift`; Test `MerchantCatalogTests/Shared/Products/ProductDTOTests.swift`; Docs `docs/Networking.md` (A14).

**Interfaces — Produces:**
- `struct Product: Identifiable, Hashable, Sendable` adds, in this order after `imageURLs`: `productDescription: String?`, `category: String?`, `tags: [String]`, `rating: Double?`, `discountPercentage: Double?`, `stock: Int?`, `sku: String?`, `weight: Double?`, `dimensions: ProductDimensions?`, `warranty: String?`, `shipping: String?`, `returnPolicy: String?`, `minimumOrderQuantity: Int?`, `reviews: [ProductReview]`.
- `struct ProductDimensions: Hashable, Sendable { let width, height, depth: Double }`; `struct ProductReview: Hashable, Sendable { let rating: Int?; let comment: String?; let reviewerName: String?; let date: Date? }`.
- DTO: all new fields optional; blank strings → `nil` (like `brand`); blank tags dropped; `dimensions` only when all three values exist; review `date` parsed as ISO 8601 with fractional seconds, else `nil`; a review with no rating, comment or name is dropped; `reviewerEmail` is not a DTO property.
- Test helper `makeProduct(id:title:price:brand:availability:thumbnailURL:imageURLs:productDescription:category:tags:rating:discountPercentage:stock:sku:weight:dimensions:warranty:shipping:returnPolicy:minimumOrderQuantity:reviews:)` with defaults (`nil` / `[]`, title "Product <id>", price `<id>.99`); `product(_:)` keeps its current values and calls it.

- [ ] **Step 1: Write failing tests:** `decodesDetailsFields` (fixture → description "A lengthening mascara for everyday wear.", category "beauty", tags `["beauty", "mascara"]`, rating 4.94, discount 7.17, stock 5, sku "BEA-ACM-001", weight 4, dimensions 15.14/13.08/22.99, warranty "1 month warranty", shipping "Ships in 1 month", returnPolicy "No return policy", MOQ 48, one review `(3, "Fine.", "Reviewer One", 2025-04-30T09:41:02.053Z)`); `missingDetailsFieldsAreEmpty` (all removed → `nil` / `[]`); `blankDetailsStringsAreNil` (parameterized over the string keys); `partialDimensionsAreNil`; `reviewsMapWithoutEmail` (`Mirror` of `ProductReview` has no label containing "email"); `malformedReviewFieldsAreNil` (date "yesterday" → `nil` date; a review `{}` is dropped).
- [ ] **Step 2:** Run → compile failure.
- [ ] **Step 3:** Implement; add A14 to Networking.md (curl 2026-11-13: `weight` integer 1–10 and `dimensions` without units, `discountPercentage` 0.04–19.61 with none 0, 10 "In Stock" products with stock ≤ 10, 4 with stock 0, reviews carry `reviewerEmail`).
- [ ] **Step 4:** Run the suite → pass.
- [ ] **Step 5:** Commit `feat: map product details fields`.

### Task 2: ProductInsights

**Files:** Create `MerchantCatalog/Shared/Products/Domain/ProductInsights.swift`; Test `MerchantCatalogTests/Shared/Products/ProductInsightsTests.swift`.

**Interfaces — Produces:** `struct ProductInsights: Equatable, Sendable { init(_ product: Product) }` with
- `enum Fact: Hashable, Sendable { case rating(Double), availability(ProductAvailability, units: Int?), stock(Int), minimumOrder(Int), shipping(String), returnPolicy(String), warranty(String), price(Decimal), discount(Double), description(String), tags([String]), sku(String), brand(String), category(String), weight(Double), dimensions(ProductDimensions) }`
- `atAGlance: [Fact]` — rating, availability (`units` = stock), minimumOrder, shipping, returnPolicy, warranty (D-55: no review count).
- `pricing: [Fact]` — price, discount only when `> 0`.
- `overview: [Fact]` — description, tags (non-empty).
- `productInformation: [Fact]` — sku, brand, category, weight, dimensions, warranty.
- `shippingAndAvailability: [Fact]` — availability (`units: nil`), stock, shipping, minimumOrder, returnPolicy.
- `reviews: [ProductReview]`. An empty array = the section is omitted.

- [ ] **Step 1: Write failing tests:** `fullProductHasEveryFact` (exact arrays in the orders above); `sparseProductKeepsOnlyCoreFacts` (Review Focus 1: only `atAGlance == [.rating(4.5)]`, `pricing == [.price(9.99)]`, every other array empty); `noBrandMeansNoBrandRow`; `zeroDiscountIsOmitted` (parameterized 0, `nil`); `availabilityCarriesStock` (`.lowStock`, stock 5 → `.availability(.lowStock, units: 5)` in At a Glance, `.availability(.lowStock, units: nil)` + `.stock(5)` in Shipping); `unknownAvailabilityKeepsStock` (availability `nil`, stock 7 → no availability fact, `.stock(7)` kept).
- [ ] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: add ProductInsights`.

### Task 3: Details presentation models

**Files:** Create `MerchantCatalog/Features/ProductDetail/Presentation/{ProductFactRow, ProductDetailHeader, ProductGalleryModel}.swift`; Test `MerchantCatalogTests/Features/ProductDetail/{ProductFactRowTests, ProductDetailHeaderTests, ProductGalleryModelTests}.swift`.

**Interfaces — Produces:**
- `struct ProductFactRow: Equatable { let label: String; let value: String; let systemImage: String; init(_ fact: ProductInsights.Fact, locale: Locale = .current) }`. Values (en_US): `.rating(4.94)` → "Rating" / "4.94"; `.availability(.lowStock, units: 5)` → "Availability" / "Low stock · 5 units" (1 → "1 unit"; `units: nil` → "Low stock"; "In stock", "Out of stock"); `.stock(5)` → "Stock" / "5 units"; `.minimumOrder(48)` → "Minimum order" / "48 units"; `.price(9.99)` → "Price" / "$9.99"; `.discount(7.17)` → "Discount" / "−7.17%" (U+2212, D-58), `.discount(7)` → "−7%"; `.weight(4)` → "Weight" / "4"; `.dimensions(15.14, 13.08, 22.99)` → "Dimensions (W × H × D)" / "15.14 × 13.08 × 22.99"; `.category("mens-shirts")` → "Category" / "Mens Shirts"; `.tags` → "Tags" / "beauty, mascara"; strings as given for shipping ("Shipping"), return policy ("Returns"), warranty ("Warranty"), sku ("SKU"), brand ("Brand"), description ("Description").
- `struct ProductDetailHeader: Equatable { let title: String; let brand: String?; let category: String?; init(_ product: Product) }` — category via the same display rule.
- `struct ProductGalleryModel: Equatable { let imageURLs: [URL]; var showsPageIndicator: Bool; init(_ product: Product) }` — full images, never the thumbnail; indicator only for ≥ 2 images.

- [ ] **Step 1: Write failing tests** with the values above (locale `en_US`); `headerWithoutBrand`; `galleryUsesFullImages` (3 images + thumbnail → the 3 images); `singleImageHidesThePageIndicator`; `noImagesMeansEmptyGallery`.
- [ ] **Step 2:** Run → compile failure. **Step 3:** Implement. **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: add product details presentation models`.

### Task 4: Details analytics events

**Files:** Modify `MerchantCatalog/Core/Analytics/AnalyticsEvent.swift`, `docs/Analytics.md`; Test `MerchantCatalogTests/Core/Analytics/DetailsAnalyticsEventTests.swift`.

**Interfaces — Produces:**
- `enum ProductSource: String, Sendable { case catalog, search }` (S5 adds `saved`); `enum ContentOrigin: String, Sendable { case list }` (S5 adds `snapshot`, `network`); `ProductAvailability.analyticsValue` (`in_stock`, `low_stock`, `out_of_stock`).
- `.productSelected(productID: Int, source: ProductSource, position: Int, sort: ProductSort)` → `product_id`, `source`, `position`, `sort`.
- `.productDetailsViewed(productID: Int, source: ProductSource, category: String?, availability: ProductAvailability?, hasDiscount: Bool, imageCount: Int, contentOrigin: ContentOrigin)` → `category` and `availability` only when non-nil.
- `.productGalleryInteracted(productID: Int, imageCount: Int)`.
- Analytics.md: the three events **Active**; `is_saved` marked "(from S5, D-56)"; `content_origin` `list` only until S5; D-59 dedup notes.

- [ ] **Step 1: Write failing tests:** exact dictionaries, e.g. `.productSelected(productID: 4, source: .search, position: 3, sort: .priceAscending)` → `["product_id": 4, "source": "search", "position": 3, "sort": "price_asc"]`; `.productDetailsViewed(productID: 1, source: .catalog, category: "beauty", availability: .lowStock, hasDiscount: true, imageCount: 3, contentOrigin: .list)` → all seven; the same with `category: nil, availability: nil` → no such keys; `.productGalleryInteracted(productID: 1, imageCount: 3)`.
- [ ] **Step 2:** Run → compile failure. **Step 3:** Implement code and docs. **Step 4:** Run → pass, `TaxonomyDocumentationTests` included.
- [ ] **Step 5:** Commit `feat: add product details analytics events`.

### Task 5: Route, router and details view model

**Files:** Create `MerchantCatalog/Core/Navigation/ProductDetailRoute.swift`, `MerchantCatalog/Features/ProductDetail/Presentation/{ProductDetailViewModel, ProductDetailConfigurator}.swift`; Modify `Core/Navigation/{Route, Router}.swift`; Test `MerchantCatalogTests/Core/Navigation/RouterTests.swift`, new `MerchantCatalogTests/Features/ProductDetail/ProductDetailViewModelTests.swift`, `MerchantCatalogTests/App/AppContextRegistrationTests.swift`.

**Interfaces — Produces:**
- `struct ProductDetailRoute: Hashable { let product: Product; let source: ProductSource }`; `enum Route: Hashable { case productDetail(ProductDetailRoute) }`; `Router.showProductDetail(_ route: ProductDetailRoute)` pushes it.
- `@MainActor @Observable final class ProductDetailViewModel { init(route: ProductDetailRoute, analytics: any AnalyticsTracking); let header: ProductDetailHeader; let insights: ProductInsights; let gallery: ProductGalleryModel; private(set) var galleryIndex: Int; func contentAppeared(); func galleryPageChanged(to index: Int) }`.
- `ProductDetailConfigurator.resolveDependencies(from:) -> Dependencies?` (analytics). Its `make(from:route:) -> ProductDetailView` comes with the view in Task 7.

- [ ] **Step 1: Write failing tests:** RouterTests' helper builds `.productDetail(ProductDetailRoute(product: product(id), source: .catalog))`; `showProductDetailPushesTheRoute`. View model: `detailsViewedOncePerScreen` (`contentAppeared()` twice → one `.productDetailsViewed(productID: 1, source: .search, category: "beauty", availability: .lowStock, hasDiscount: true, imageCount: 3, contentOrigin: .list)`); `eachPushTracksItsOwnView` (two view models → two events); `galleryEventFiresOnceOnTheFirstSwipe` (`to: 0` → none; `to: 1` → `.productGalleryInteracted(productID: 1, imageCount: 3)`; `to: 2`, `to: 0` → none; `galleryIndex == 0`); `exposesHeaderInsightsAndGallery`. Registration: `productDetailDependenciesResolve`.
- [ ] **Step 2:** Run → compile failure. **Step 3:** Implement (the S0 placeholder destination in `AppTabView` switches on the new payload, still a `Text` until Task 7). **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: add product details route and view model`.

### Task 6: Card selection from the catalog

**Files:** Modify `Features/Catalog/Presentation/{CatalogViewModel, CatalogConfigurator}.swift`, `App/AppTabView.swift` (passes `catalogRouter`); Test new `MerchantCatalogTests/Features/Catalog/CatalogViewModelSelectionTests.swift`, call sites in the other three catalog view-model suites.

**Interfaces — Produces:** `CatalogViewModel.init(repository:analytics:router:clock:)` (`router: Router`, required); `func cardSelected(id: Product.ID, in context: ListContext)` — ignored for a hidden list or an unknown id; else `product_selected` (`source` `.catalog` / `.search` from the list, `position` = index in that list, `sort` of that list), then `router.showProductDetail`. `searchDismissed()` returns early while `!router.path.isEmpty` (D-54). `CatalogConfigurator.make(from:router:isTabSelected:)`.

- [ ] **Step 1: Write failing tests** (`@Suite(.timeLimit(.minutes(1)))`): `selectingABrowseCardTracksAndPushes` (id 4 → `.productSelected(productID: 4, source: .catalog, position: 3, sort: .defaultOrder)`, `router.path == [.productDetail(.init(product: product(4), source: .catalog))]`); `selectingASearchResultUsesTheSearchList` (search "phone" with ids 101…103, sort changed to `.priceAscending` → select 102 → `source: .search, position: 1, sort: .priceAscending`); `positionCountsLoadedPages` (page 2 loaded → id 25 → `position: 24`); `hiddenListCardIsIgnored` (while searching, `cardSelected(id: 4, in: .browse)` → no event, empty path); `unknownCardIsIgnored`; `searchSurvivesDismissalWhileDetailsArePushed` (search loaded, card selected, `searchDismissed()` → `listContext == .search`, `searchText == "phone"`, no `search_cleared`, no request; `router.pop()` then `searchDismissed()` → browse, one `search_cleared`); `returningFromDetailsKeepsBrowseState` (40 cards, sort `.ratingDescending`; select, pop → same cards, sort, no request).
- [ ] **Step 2:** Run → compile failure, then assertion failures. **Step 3:** Implement. **Step 4:** Run the suite → pass.
- [ ] **Step 5:** Commit `feat: open product details from the catalog`.

### Task 7: Details UI

**Files:** Create `MerchantCatalog/Features/ProductDetail/Presentation/{ProductDetailView, ProductGalleryView}.swift`; Modify `ProductDetailConfigurator.swift` (`make`), `App/AppTabView.swift` (destination), `Features/Catalog/Presentation/CatalogView.swift` (card `Button`, `.buttonStyle(.plain)`).

**Interfaces — Produces:** `ProductDetailView(viewModel:)` owns its view model in `@State`; a `ScrollView` with the gallery (page-style `TabView` bound to `galleryIndex` / `galleryPageChanged(to:)`, `ProductImageView` per page, indicator per `showsPageIndicator`, each page an image element "Image n of m"), the header (title as a header trait, brand, category), then each non-empty section with its exact title (Global Constraints), facts as `ProductFactRow`s (At a Glance as chips), reviews as rating stars + comment + name + date (`.abbreviated`). `.onAppear { viewModel.contentAppeared() }`. Inline navigation bar, no title.

- [ ] **Step 1:** Implement. No layout unit tests (no snapshot tests).
- [ ] **Step 2:** Run the full suite → pass, `NavigationRuleTests` included.
- [ ] **Step 3:** Commit `feat: add the product details screen`.

### Task 8: Docs and review gate

**Files:** `docs/ProductSpecification.md` § 4.3 (D-55, D-58), `docs/Architecture.md` (§ 2 files, § 6 Configurator, § 7 as built), `docs/Networking.md` (A14, § 2 note: `.detail` arrives in S5), `docs/ImplementationPlan.md` (D-53–D-59, review log, status), README status line, AILog, this plan's checkboxes and deviations.

- [ ] **Step 1:** `xcodebuild … clean build` → `** BUILD SUCCEEDED **`; result bundle `warningCount: 0`.
- [ ] **Step 2:** `xcodebuild … -configuration Release build` → succeeds, 0 warnings.
- [ ] **Step 3:** `xcodebuild … test` → all pass; record counts.
- [ ] **Step 4:** Update docs and the review log (manual Simulator checks: products 1 (1 image, brand), 16 (1 image, no brand), 167 (6 images), 117 (out of stock), 92 (discount 0.04 %); back restores scroll and search; VoiceOver pass); status `READY_FOR_REVIEW`.
- [ ] **Step 5:** Commit `docs: record S4 review gate`.

## Deviations found during implementation

*(filled in during implementation)*
