# S2 — Catalog Browsing, Networking and Images Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merchants browse the whole catalog in a 2-column grid with skeleton, load-more, page-error, pull-to-refresh, empty and full-screen error states, over a cache-free, protocol-first network layer, with images that load only for visible cells and the eight catalog analytics events.

**Architecture:** `URLSessionAPIClient` (the only `URLSession` user, behind `APIClientType`) builds requests from Moya-style `TargetType`s, maps failures to `AppError`, logs to `network`, and decodes off the main actor. `LiveProductRepository` (behind `ProductRepository`) maps DTOs to the domain `Product`. `CatalogListState` (pure) owns pagination and de-duplication; `CatalogViewModel` (`@MainActor @Observable`) owns loading flags, a generation counter, the page task and analytics; `CatalogView` renders `CatalogPhase`. `CatalogConfigurator` builds the tab root for `AppTabView`.

**Tech Stack:** Xcode 26.0, Swift 6.2 compiler in Swift 6 language mode, SwiftUI (iOS 26.0), Observation, `URLSession` async API, `Synchronization.Mutex`, `os.Logger`, Swift Testing. No packages.

**Spec:** [ImplementationPlan.md § S2](../ImplementationPlan.md#s2--catalog-browsing-networking-and-images), [Networking.md](../Networking.md), [ProductSpecification.md § 4.1](../ProductSpecification.md#41-catalog-browse), [Analytics.md § 3 Catalog, Reliability](../Analytics.md#catalog), [Architecture.md § 3–§ 8, § 10](../Architecture.md).

## Global Constraints

- Neutral naming only (`MerchantCatalog`). No third-party dependencies.
- **No caching:** the client's configuration has `urlCache = nil` and `requestCachePolicy = .reloadIgnoringLocalCacheData`; every `URLRequest` also uses `.reloadIgnoringLocalCacheData`. No image cache, no response cache.
- `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; no default actor isolation (D-31). Verified on this branch with `-showBuildSettings` (2026-11-13).
- `@MainActor` only on view models, views' helpers, the DEBUG setting and test fakes that need it. `URLSessionAPIClient`, `LiveProductRepository`, DTOs and domain types are `Sendable`; no `@unchecked Sendable` / `nonisolated(unsafe)` in app code.
- View models depend only on `ProductRepository` and `AnalyticsTracking`; only `AppContext` names concrete types; services are registered under their protocol.
- Page size **20**; next page when one of the last **5** cards appears; one page request in flight; de-dup by `id`; end when `skip + count >= total`.
- Request timeout **15 s**. Base URL `https://dummyjson.com`. DEBUG slow network appends `delay=2000` to every API request.
- Analytics: no free text; `CancellationError` / `URLError.cancelled` is never a failure (no event, no error UI). Analytics code and `docs/Analytics.md` change in the same commit.
- `NavigationStack` / `navigationDestination` only in `App/AppTabView.swift`; no `NavigationLink`.
- DEBUG-only code wrapped in `#if DEBUG`; the Release configuration must compile.
- Verify with `xcodebuild build` (0 warnings in the result bundle) and `xcodebuild test` on `platform=iOS Simulator,name=iPhone 17,OS=26.0`. Never launch or drive the app in the Simulator.

## Decisions taken in this plan

| ID | Decision | By | Why |
|---|---|---|---|
| D-37 | S2 maps only the fields S2 uses or its mapping tests name: `id`, `title`, `price`, `thumbnail`, `images`, optional `brand`, `availabilityStatus`. S4 adds the details fields with its own tests | Developer (scope) | Smaller decode surface: fewer ways a page can fail to decode. |
| D-38 | The empty state's Reload loads page 1 with `trigger: reload`; it sends no `retry_requested` (nothing failed). Analytics.md gains the `reload` value | Developer (scope) | Keeps retry outcomes paired 1:1 with `retry_requested`. |
| D-39 | `catalog_viewed` fires on the first display at launch and on each switch back to the Catalog tab, driven by `AppTabView`'s selection; not on popping back from details, not on returning from the background | Developer (scope) | Tab visibility is the meaning; push/pop and app lifecycle have their own signals. |
| D-40 | `duration_ms` is measured with an injected monotonic `any Clock<Duration>` (`ContinuousClock` in the app, `TestClock` in tests); D-35's wall clock stays for sessions | Agent | Request latency must not jump with the wall clock; S3's debounce uses the same injected clock. |
| D-41 | Pull-to-refresh sends only `catalog_refreshed` (never `catalog_load_completed` / `catalog_load_failed`). It cancels an in-flight page load (its result is dropped by generation) and pauses load-more until it ends. A refresh failure shows a dismissible banner, cleared by the next refresh | Agent | One event per meaning; one page request in flight; no stale page appended to a fresh page 1. |
| D-42 | DEBUG slow network: `delay=2000` (ms) on every API request, persisted in `UserDefaults` (DEBUG only) so a relaunch shows the skeleton | Agent | The skeleton only appears on a first-page load; persisting the toggle makes it checkable at launch. |
| D-43 | `URLError` codes outside Networking.md's table (e.g. `cannotFindHost`) map to `.unknown`; any non-2xx other than 404/429 maps to `.server(status:)`; a non-HTTP response maps to `.unknown` | Agent | Follows the documented table exactly; no guessing which other codes mean "offline". |

## Review Focus

1. **The API returns an empty page before `total`** (inconsistent data) → pagination stops instead of re-requesting the same `skip` forever → Task 4 `emptyPageStopsPagination`.
2. **Pull-to-refresh while page 2 is in flight** → page 2's late result is dropped, no duplicate cards, no `catalog_page_loaded` → Task 8 `refreshDropsAnInFlightPageResult`.
3. **The user switches tabs during the first load** (`.task` is cancelled) → no failure UI or event; returning to the tab loads again → Task 6 `cancelledStartLeavesSkeletonAndRestarts`.
4. **A product with no brand, a blank brand, an unknown availability or a malformed image URL** → the page still decodes; the field is `nil` / dropped → Task 3 `brandMapping`, `availabilityMapping`, `invalidImageURLsAreDropped`.
5. **An unexpected status (400) or transport error (`cannotFindHost`)** → a reason-specific state (`.server(status: 400)` / `.unknown`), never a crash or a silent hang → Task 2 `mapsHTTPStatus`, `mapsTransportErrors`.

---

### Task 1: Endpoint model

**Files:**
- Create: `MerchantCatalog/Networking/{HTTPMethod, APIConfig, TargetType}.swift`, `MerchantCatalog/Shared/Products/Domain/ProductSort.swift`, `MerchantCatalog/Shared/Products/Data/ProductsTarget.swift`
- Test: `MerchantCatalogTests/Shared/Products/ProductsTargetTests.swift`

**Interfaces — Produces:**
- `enum HTTPMethod: String, Sendable { case get = "GET" }`.
- `enum APIConfig { static let baseURL: URL /* https://dummyjson.com */; static let defaultTimeout: TimeInterval = 15 }`.
- `protocol TargetType: Sendable { var baseURL: URL; var path: String; var method: HTTPMethod; var queryItems: [URLQueryItem]; var headers: [String: String]; var timeout: TimeInterval }` (all `{ get }`), with extension defaults: `APIConfig.baseURL`, `.get`, `[]`, `[:]`, `APIConfig.defaultTimeout`.
- `enum ProductSort: CaseIterable, Sendable { case defaultOrder, priceAscending, priceDescending, ratingDescending }`.
- `enum ProductsTarget: TargetType { case list(skip: Int, limit: Int, sort: ProductSort) }` — path `/products`; query items in this order: `limit`, `skip`, then `sortBy`, `order` (absent for `.defaultOrder`).

- [x] **Step 1: Write failing tests.** `listQueryItems` (parameterized over the four sorts): `.list(skip: 20, limit: 20, sort:)` → `[limit=20, skip=20]` + `[]` / `[sortBy=price, order=asc]` / `[sortBy=price, order=desc]` / `[sortBy=rating, order=desc]`. `listDefaults`: path `/products`, method `.get`, `baseURL == URL(string: "https://dummyjson.com")`, `timeout == 15`, `headers == [:]`.
- [x] **Step 2:** Run → compile failure.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add TargetType and ProductsTarget.list`.

### Task 2: URLSessionAPIClient

**Files:**
- Create: `MerchantCatalog/Networking/{APIClientType, AppError, RequestDelay, NetworkLogger, URLSessionAPIClient}.swift`
- Create: `MerchantCatalogTests/Fakes/StubURLProtocol.swift`
- Test: `MerchantCatalogTests/Networking/{URLSessionAPIClientTests, NetworkLoggerTests}.swift`

**Interfaces — Produces:**
- `protocol APIClientType: Sendable { func request<Response: Decodable & Sendable>(_ target: some TargetType) async throws -> Response }`.
- `enum AppError: Error, Equatable, Sendable { case offline, timeout, notFound, rateLimited, server(status: Int), decoding, unknown }`; `var httpStatus: Int?` (404, 429, the server status; otherwise `nil`); `var userMessage: String` (copy below).
- `final class RequestDelay: Sendable` — `init(_ value: Duration? = nil)`; `var value: Duration? { get }`; `func set(_ value: Duration?)` (a `Mutex`).
- `enum NetworkLogger` — `static func sanitizedURL(_ url: URL) -> String` (the `q` value → `<private>`); `static func makeRequestID() -> String` (8 characters); logging helpers for start / response / failure / cancellation on `Log.network` (debug for success and cancellation, error for failures; ids, status, latency in ms and size `.public`).
- `final class URLSessionAPIClient: APIClientType` — `init(configuration: URLSessionConfiguration = .default, delay: RequestDelay = RequestDelay())` (sets `urlCache = nil`, `requestCachePolicy = .reloadIgnoringLocalCacheData` on the configuration it owns); `let session: URLSession`; `static func makeRequest(for target: some TargetType, delay: Duration?) throws -> URLRequest` (throws `AppError.unknown` if the URL can't be built; appends `delay=<ms>` when `delay` is set); `request` is `@concurrent`, decodes with a `JSONDecoder`, maps errors per Networking.md § 2 and D-43; `URLError.cancelled` / `CancellationError` → `CancellationError`.
- Test support: `StubURLProtocol` routes by host, so tests run in parallel: `static func register(_ response: StubURLProtocol.Response) -> StubURLProtocol.Stub`; `enum Response: Sendable { case http(status: Int, body: Data), failure(URLError.Code), never }`; `Stub` has `host: String`, `makeConfiguration() -> URLSessionConfiguration` (ephemeral, `protocolClasses = [StubURLProtocol.self]`), `requests: [URLRequest]`, `func waitForRequest() async`. Tests call the client with a private `StubTarget` whose `baseURL` is `https://<stub.host>`.

User messages (exact copy): offline "You're offline. Check your connection and try again." · timeout "This is taking too long. Try again." · notFound "This product is no longer available." · rateLimited "Too many requests. Try again in a moment." · server "Something went wrong on our side. Try again later." · decoding "We received unexpected data. Try again later." · unknown "Something went wrong. Try again."

- [x] **Step 1: Write failing tests.** `decodesA2xxResponse` (`{"value": 7}` → `Echo(value: 7)`). `mapsHTTPStatus` (parameterized: 404 → `.notFound`, 429 → `.rateLimited`, 500 → `.server(status: 500)`, 503 → `.server(status: 503)`, 400 → `.server(status: 400)`). `mapsTransportErrors` (parameterized: `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed` → `.offline`; `.timedOut` → `.timeout`; `.cannotFindHost` → `.unknown`). `malformedJSONIsDecodingError`. `cancellationThrowsCancellationError` (`.never` stub, `waitForRequest()`, cancel the task, expect `CancellationError`). `requestUsesNoCache` (`session.configuration.urlCache == nil`, `requestCachePolicy == .reloadIgnoringLocalCacheData`, the stub's received request has `.reloadIgnoringLocalCacheData`). `buildsRequestFromTarget` (`makeRequest(for: ProductsTarget.list(skip: 0, limit: 20, sort: .defaultOrder), delay: nil)` → URL `https://dummyjson.com/products?limit=20&skip=0`, `httpMethod == "GET"`, `timeoutInterval == 15`, `cachePolicy == .reloadIgnoringLocalCacheData`). `slowNetworkDelayAddsQueryItem` (`delay: .milliseconds(2000)` → URL ends with `&delay=2000`). `httpStatusAndMessages` (parameterized: `httpStatus` per case; every `userMessage` non-empty and distinct). `NetworkLoggerTests.redactsSearchQuery` (`…/products/search?q=red%20shoes&limit=20` → `…/products/search?q=<private>&limit=20`; a URL without `q` is unchanged).
- [x] **Step 2:** Run → compile failure.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add URLSessionAPIClient without caching`.

### Task 3: Product domain, DTO mapping and repository

**Files:**
- Create: `MerchantCatalog/Shared/Products/Domain/{Product, ProductPage, ProductRepository}.swift`, `MerchantCatalog/Shared/Products/Data/{ProductDTO, LiveProductRepository}.swift`
- Create: `MerchantCatalogTests/Fakes/FakeAPIClient.swift`
- Test: `MerchantCatalogTests/Shared/Products/{ProductDTOTests, LiveProductRepositoryTests}.swift`

**Interfaces — Produces:**
- `struct Product: Identifiable, Equatable, Sendable { let id: Int; let title: String; let price: Decimal; let brand: String?; let availability: ProductAvailability?; let thumbnailURL: URL?; let imageURLs: [URL] }`; `enum ProductAvailability: Equatable, Sendable { case inStock, lowStock, outOfStock }`.
- `struct ProductPage: Equatable, Sendable { let products: [Product]; let total: Int; let skip: Int; let limit: Int }`.
- `protocol ProductRepository: Sendable { func products(sort: ProductSort, skip: Int, limit: Int) async throws -> ProductPage }`.
- `struct ProductListResponseDTO: Decodable, Sendable { products: [ProductDTO]; total, skip, limit: Int; func toDomain() -> ProductPage }`; `struct ProductDTO: Decodable, Sendable` — required `id`, `title`, `price: Decimal`; optional `brand`, `availabilityStatus`, `thumbnail`, `images`; `func toDomain() -> Product` (blank brand → `nil`; `"In Stock"` / `"Low Stock"` / `"Out of Stock"` → cases, anything else → `nil`; invalid URLs dropped / `nil`).
- `struct LiveProductRepository: ProductRepository { init(client: any APIClientType) }` — requests `ProductsTarget.list(skip:limit:sort:)`, decodes `ProductListResponseDTO`, maps off the main actor.
- `@MainActor final class FakeAPIClient: APIClientType` — `var responseJSON: Data`, `var error: (any Error)?`; records `requests: [(path: String, queryItems: [URLQueryItem])]`; decodes `responseJSON` into the requested type.

- [x] **Step 1: Write failing tests** (a realistic product JSON fixture with extra fields such as `reviews`, `dimensions` that S2 ignores). `decodesProductFixture` (price `Decimal(string: "9.99")` exactly, title, id, thumbnail URL, 3 image URLs). `brandMapping` (parameterized: missing → nil, `""` → nil, `"  "` → nil, `"Apple"` → `"Apple"`). `availabilityMapping` (parameterized: the three values, `"Discontinued"` → nil, missing → nil). `invalidImageURLsAreDropped` (`["https://a.test/1.webp", ""]` → one URL; missing `images` → `[]`; missing `thumbnail` → nil). `pageMapping` (`total`, `skip`, `limit`, order of products). Repository: `requestsListTargetAndMapsPage` (path `/products`, items `limit=20, skip=40, sortBy=price, order=asc`; mapped page equals the DTO's `toDomain()`), `propagatesClientErrors` (`AppError.offline` rethrown).
- [x] **Step 2:** Run → compile failure.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add product DTO mapping and LiveProductRepository`.

### Task 4: CatalogListState

**Files:** Create `MerchantCatalog/Features/Catalog/Domain/CatalogListState.swift`; Test `MerchantCatalogTests/Features/Catalog/CatalogListStateTests.swift`; Create `MerchantCatalogTests/Fakes/ProductFixtures.swift` (`func product(_ id: Int) -> Product`, `func page(_ ids: ClosedRange<Int>, total: Int, skip: Int) -> ProductPage`).

**Interfaces — Produces:** `struct CatalogListState: Equatable, Sendable` — `private(set) var items: [Product]`, `total: Int`, `nextSkip: Int`, `pagesLoaded: Int`; `var canLoadMore: Bool` (`pagesLoaded > 0`, the last page was not empty, `nextSkip < total`); `var isEmpty: Bool`; `mutating func replace(with page: ProductPage)` (page 1, starts over); `@discardableResult mutating func append(_ page: ProductPage) -> Int` (new unique items). `nextSkip = page.skip + page.products.count` (raw count, so duplicates don't shift the offset).

- [x] **Step 1: Write failing tests:** `startsWithNothingToLoad` (`!canLoadMore`, empty); `replaceStartsOver`; `appendAddsOnlyNewIDs` (page 2 repeats two ids → returns 18, `items.count == 38`, `nextSkip == 40`); `canLoadMoreUntilTotal` (total 45: 20 → true, 40 → true, 45 → false); `emptyFirstPageIsEmpty` (total 0); `emptyPageStopsPagination` (Review Focus 1).
- [x] **Step 2:** Run → compile failure.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add CatalogListState`.

### Task 5: Catalog analytics events

**Files:** Modify `MerchantCatalog/Core/Analytics/AnalyticsEvent.swift`, `docs/Analytics.md` (8 events → **Active**; `trigger` gains `reload` (D-38); `catalog_viewed` trigger per D-39; `catalog_refreshed` note per D-41; `http_status` only for HTTP failures); Test `MerchantCatalogTests/Core/Analytics/AnalyticsEventTests.swift`.

**Interfaces — Produces:**
- New `AnalyticsEventName` cases: `catalogViewed`, `catalogLoadCompleted`, `catalogLoadFailed`, `catalogRefreshed`, `catalogPageRequested`, `catalogPageLoaded`, `catalogPageFailed`, `retryRequested` (raw values = the snake_case names).
- `enum ListContext: String, Sendable { case browse }`; `enum CatalogLoadTrigger: String, Sendable { case initial, retry, reload }`; `enum RefreshOutcome: Equatable, Sendable { case success, failure(AppError) }`; `enum FailedSurface: String, Sendable { case catalog, catalogPage = "catalog_page" }`. S3/S4 add `search`, `sort_change`, `details`.
- `AnalyticsEvent` cases: `.catalogViewed(sort: ProductSort, listContext: ListContext)`, `.catalogLoadCompleted(trigger: CatalogLoadTrigger, sort: ProductSort, resultCount: Int, totalCount: Int, durationMs: Int)`, `.catalogLoadFailed(trigger: CatalogLoadTrigger, sort: ProductSort, error: AppError, hasVisibleContent: Bool)`, `.catalogRefreshed(listContext: ListContext, outcome: RefreshOutcome, durationMs: Int)`, `.catalogPageRequested(listContext: ListContext, pageIndex: Int, sort: ProductSort, isRetry: Bool)`, `.catalogPageLoaded(listContext: ListContext, pageIndex: Int, itemCount: Int, hasMore: Bool, durationMs: Int)`, `.catalogPageFailed(listContext: ListContext, pageIndex: Int, error: AppError)`, `.retryRequested(failedSurface: FailedSurface, error: AppError)`.
- `extension ProductSort { var analyticsValue: String }` (`default_order`, `price_asc`, `price_desc`, `rating_desc`); `extension AppError { var analyticsErrorType: String }` (`offline`, `timeout`, `not_found`, `rate_limited`, `server`, `decoding`, `unknown`).

- [x] **Step 1: Write failing tests:** extend `namesAndProperties` with one row per new case, exact dictionaries, e.g. `.catalogLoadFailed(trigger: .retry, sort: .defaultOrder, error: .server(status: 503), hasVisibleContent: false)` → `["trigger": "retry", "sort": "default_order", "error_type": "server", "http_status": 503, "has_visible_content": false]`; `.catalogLoadFailed(… error: .offline …)` has no `http_status`; `.catalogRefreshed(listContext: .browse, outcome: .success, durationMs: 120)` → `["list_context": "browse", "result": "success", "duration_ms": 120]` (no `error_type`); `.retryRequested(failedSurface: .catalogPage, error: .timeout)` → `["failed_surface": "catalog_page", "error_type": "timeout"]`. `sortAnalyticsValues` and `errorTypes` (parameterized). `TaxonomyDocumentationTests` stays green with the docs flipped.
- [x] **Step 2:** Run → compile failure.
- [x] **Step 3:** Implement; flip the eight statuses and add the notes in Analytics.md.
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add catalog analytics events`.

### Task 6: CatalogViewModel — first page and catalog_viewed

**Files:**
- Create: `MerchantCatalog/Features/Catalog/Presentation/{CatalogViewModel, CatalogPhase, ProductCardModel}.swift`, `MerchantCatalog/Core/Time/Clock+Stopwatch.swift`
- Create: `MerchantCatalogTests/Fakes/FakeProductRepository.swift`, `MerchantCatalogTests/Support/TestClock.swift`
- Test: `MerchantCatalogTests/Features/Catalog/CatalogViewModelTests.swift`, `MerchantCatalogTests/Features/Catalog/ProductCardModelTests.swift`

**Interfaces — Produces:**
- `extension Clock where Duration == Swift.Duration { func stopwatch() -> () -> Swift.Duration }`; `extension Duration { var wholeMilliseconds: Int }` (rounded down, never negative).
- `struct ProductCardModel: Identifiable, Equatable { let id: Int; let title: String; let price: String; let thumbnailURL: URL?; init(product: Product, locale: Locale = .current); static func placeholder(id: Int) -> ProductCardModel }` — price formatted as USD currency in `locale`.
- `enum CatalogFooter: Equatable { case idle, loading, failed(AppError), end }`; `enum CatalogPhase: Equatable { case initialLoading, content(footer: CatalogFooter, refreshError: AppError?), empty, failed(AppError) }`.
- `@MainActor @Observable final class CatalogViewModel` — `static let pageSize = 20`, `static let prefetchDistance = 5`; `init(repository: any ProductRepository, analytics: any AnalyticsTracking, clock: any Clock<Duration> = ContinuousClock())`; `private(set) var cards: [ProductCardModel]`; `var phase: CatalogPhase`; `let sort: ProductSort = .defaultOrder` (S3 makes it changeable); `func start() async` (loads page 1 with `trigger: initial` only if nothing is loaded or loading; structured, called from `.task`); `func catalogBecameVisible()`; `func retry()` (full-screen Retry: `retry_requested(catalog)`, then page 1 with `trigger: retry`); `func reload()` (empty Reload: page 1 with `trigger: reload`); `private(set) var firstPageTask: Task<Void, Never>?` (the handle `retry()` / `reload()` start; tests await it). Every page-1 request increments a private `generation`; a result whose generation is no longer current is dropped. Cancellation → no state change, no event. Logs first-page latency to `Log.performance` (info).
- Test support: `@MainActor final class FakeProductRepository: ProductRepository` — `struct Request: Equatable { sort, skip, limit }`; `private(set) var requests: [Request]`; `func enqueue(_ result: Result<ProductPage, any Error>)`; a call with nothing queued suspends until `resumeNext(with:)`; `func waitForPendingRequests(_ count: Int) async` (continuation, no polling); `var onRequest: (() -> Void)?` (runs when a request arrives, e.g. to advance the clock). `final class TestClock: Clock, Sendable` (`Mutex` state; `Instant` wraps a `Duration` offset; `func advance(by: Duration)`; `sleep` records an `Issue` and throws `CancellationError` until S3's debounce needs it).

- [x] **Step 1: Write failing tests:** `ProductCardModelTests`: `exposesThumbnailURL`; `formatsPriceAsUSD` (`en_US`, 9.99 → `"$9.99"`); `placeholderHasNoImage`. `CatalogViewModelTests`: `startsInInitialLoading`; `startLoadsFirstPage` (request `(.defaultOrder, 0, 20)`; 20 cards; phase `.content(footer: .idle, refreshError: nil)`; event `.catalogLoadCompleted(trigger: .initial, sort: .defaultOrder, resultCount: 20, totalCount: 194, durationMs: 250)` with `onRequest` advancing the clock 250 ms); `startFailureShowsError` (`.failed(.offline)`; `.catalogLoadFailed(trigger: .initial, sort: .defaultOrder, error: .offline, hasVisibleContent: false)`); `retryAfterFailureLoadsContent` (events `retry_requested(catalog, offline)` then `catalog_load_completed(trigger: retry)`; phase content); `emptyResponseShowsEmpty`; `reloadFromEmptyUsesReloadTrigger` (no `retry_requested`); `cancelledStartLeavesSkeletonAndRestarts` (Review Focus 3: `CancellationError` → `.initialLoading`, no events; a second `start()` loads); `startAfterContentDoesNothing` (one request); `catalogBecameVisibleTracksView` (`.catalogViewed(sort: .defaultOrder, listContext: .browse)` per call).
- [x] **Step 2:** Run → compile failure.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add CatalogViewModel first-page loading`.

### Task 7: CatalogViewModel — pagination

**Files:** Modify `CatalogViewModel.swift`; Test `CatalogViewModelTests.swift` (new tests).

**Interfaces — Produces:** `func itemAppeared(id: Product.ID)` (starts the next page when `id` is among the last `prefetchDistance` cards, content is shown, `canLoadMore`, no page task, no page error, not refreshing); `func retryPage()` (footer Retry: `retry_requested(catalog_page, error)`, then the same page with `is_retry: true`); `private(set) var pageTask: Task<Void, Never>?`. `page_index = pagesLoaded + 1`; `item_count` = new unique items; `has_more` = `canLoadMore` after appending.

- [x] **Step 1: Write failing tests:** `nearEndLoadsNextPage` (`itemAppeared(15)` → no request; `itemAppeared(16)` → request `skip 20`; events `.catalogPageRequested(listContext: .browse, pageIndex: 2, sort: .defaultOrder, isRetry: false)` and `.catalogPageLoaded(listContext: .browse, pageIndex: 2, itemCount: 20, hasMore: true, durationMs: 80)`; footer `.idle`); `loadMoreIsSingleFlight` (page pending: a second `itemAppeared` makes no request and no event); `pageFailureKeepsContent` (`.timeout` → 20 cards, footer `.failed(.timeout)`, `.catalogPageFailed(listContext: .browse, pageIndex: 2, error: .timeout)`; another `itemAppeared` → no request); `retryPageAppends` (`retry_requested(catalog_page, timeout)`, `is_retry: true`, 40 cards, footer `.idle`); `noRequestPastTheEnd` (total 45: pages 20, 20, 5 → footer `.end`; `itemAppeared(45)` → no request); `duplicateIDsAreDropped` (page 2 repeats ids 19–20 → `itemCount: 18`); `loadsWholeCatalogWithoutDuplicates` (AC-C2: total 194, 10 pages → 194 unique cards, footer `.end`, 10 requests); `cancelledPageLoadSendsNothing`.
- [x] **Step 2:** Run → fail (missing members).
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add catalog pagination`.

### Task 8: CatalogViewModel — pull-to-refresh

**Files:** Modify `CatalogViewModel.swift`; Test `CatalogViewModelTests.swift`.

**Interfaces — Produces:** `func refresh() async` (page 1 for the current sort; success → replace list, clear page error; failure → keep content, `refreshError`; cancels `pageTask`; tracks `.catalogRefreshed`); `func dismissRefreshError()`.

- [x] **Step 1: Write failing tests:** `refreshReplacesContent` (`.catalogRefreshed(listContext: .browse, outcome: .success, durationMs: 120)`; no `catalog_load_completed`); `refreshFailureKeepsContent` (cards unchanged; phase `.content(footer: .idle, refreshError: .offline)`; `outcome: .failure(.offline)`); `refreshDropsAnInFlightPageResult` (Review Focus 2: page 2 pending, `refresh()` succeeds, then page 2 resumes with success → 20 cards, no `catalog_page_loaded`); `loadMoreIsPausedDuringRefresh`; `dismissRefreshErrorClearsBanner`; `nextRefreshClearsBanner`; `cancelledRefreshSendsNothing`.
- [x] **Step 2:** Run → fail.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add catalog pull-to-refresh`.

### Task 9: Catalog UI and composition

**Files:**
- Create: `MerchantCatalog/DesignSystem/Components/ProductImageView.swift` (Networking.md § 4 design: fixed-size placeholder, `AsyncImage` only while visible, `.id(url)`, failure icon), `MerchantCatalog/Features/Catalog/Presentation/{ProductCardView, CatalogView, CatalogConfigurator}.swift`
- Modify: `MerchantCatalog/App/AppTabView.swift` (Catalog root = `CatalogConfigurator.make(from: container, isTabSelected: selection == .catalog)`; DEBUG toolbar and `navigationDestination` stay here), `MerchantCatalog/App/AppContext.swift` (register `URLSessionAPIClient` as `any APIClientType`, `LiveProductRepository` as `any ProductRepository`; one `RequestDelay` shared with Task 10)
- Test: `MerchantCatalogTests/App/AppContextRegistrationTests.swift`

**Interfaces — Produces:**
- `struct ProductImageView: View { init(url: URL?) }`.
- `struct ProductCardView: View { init(card: ProductCardModel) }` — square image, title (2 lines, space reserved), price; one accessibility element ("title, price").
- `struct CatalogView: View { init(viewModel: CatalogViewModel, isTabSelected: Bool) }` — skeleton grid (8 redacted placeholder cards), 2-column `LazyVGrid` with `itemAppeared` per card, footer (spinner / message + Retry / "You've reached the end"), `.refreshable`, refresh-error banner with a close button, `ContentUnavailableView` for empty (Reload) and failed (reason message, Retry); `.task { await viewModel.start() }`; `.onChange(of: isTabSelected, initial: true)` → `catalogBecameVisible()` when selected.
- `@MainActor enum CatalogConfigurator { struct Dependencies { repository: any ProductRepository; analytics: any AnalyticsTracking }; static func resolveDependencies(from: any ServiceContainerType) -> Dependencies?; static func make(from: any ServiceContainerType, isTabSelected: Bool) -> CatalogView }`.

- [x] **Step 1: Write failing tests:** `catalogDependenciesResolve`; `networkServicesAreRegistered` (`any APIClientType`, `any ProductRepository`).
- [x] **Step 2:** Run → compile failure.
- [x] **Step 3:** Implement the views, Configurator, AppTabView and AppContext changes. No new unit tests for view layout (no snapshot tests); behavior lives in the view model.
- [x] **Step 4:** Run the full suite → pass, `NavigationRuleTests` included.
- [x] **Step 5:** Commit `feat: add catalog grid UI`.

### Task 10: DEBUG slow-network toggle

**Files:**
- Create: `MerchantCatalog/Features/Diagnostics/Domain/SlowNetworkSetting.swift` (`#if DEBUG`)
- Modify: `DiagnosticsViewModel.swift`, `DiagnosticsView.swift` (a "Network" section with the toggle), `DiagnosticsConfigurator.swift`, `AppContext.swift` (DEBUG: register `SlowNetworkSetting` built on the client's `RequestDelay`)
- Test: `MerchantCatalogTests/Features/Diagnostics/{SlowNetworkSettingTests, DiagnosticsViewModelTests}.swift`

**Interfaces — Produces:** `@MainActor final class SlowNetworkSetting` — `static let delay: Duration = .milliseconds(2000)`; `init(defaults: UserDefaults, requestDelay: RequestDelay)` (applies the persisted value); `var isEnabled: Bool` (persists under `diagnostics.slow_network`, sets `requestDelay` to `delay` or `nil`). `DiagnosticsViewModel` gains `slowNetwork: SlowNetworkSetting` in `init` and `var isSlowNetworkEnabled: Bool` (stored, forwards to the setting).

- [x] **Step 1: Write failing tests:** `offByDefault` (`requestDelay.value == nil`); `enablingSetsDelayAndPersists`; `persistedValueIsAppliedAtInit` (new instance on the same defaults → delay 2 s); `toggleForwardsToSetting` (view model); `diagnosticsDependenciesResolve` stays green.
- [x] **Step 2:** Run → compile failure.
- [x] **Step 3:** Implement.
- [x] **Step 4:** Run → pass.
- [x] **Step 5:** Commit `feat: add DEBUG slow-network toggle`.

### Task 11: Docs and review gate

**Files:** `docs/Architecture.md` (§ 2 what exists, § 5 clock, § 8 `CatalogPhase` as built), `docs/Networking.md` (§ 2 as built; § 4 verification still pending), `docs/ImplementationPlan.md` (D-37–D-43, review log, status), README status line, this plan's checkboxes, `docs/AILog.md` if the developer changed AI output.

- [x] **Step 1:** `xcodebuild … clean build` → `** BUILD SUCCEEDED **`; `xcrun xcresulttool get build-results` → `warningCount: 0`.
- [x] **Step 2:** `xcodebuild … -configuration Release build` → succeeds.
- [x] **Step 3:** `xcodebuild … test` → all pass; record counts.
- [x] **Step 4:** Update docs and the review log (manual Simulator checks, limitations, open questions); status `READY_FOR_REVIEW`.
- [x] **Step 5:** Commit `docs: record S2 review gate`.

## Deviations found during implementation

- Task 2: `Duration.wholeMilliseconds` (`Core/Time/Duration+Milliseconds.swift`) was written here, because the `delay` query item needs it; its tests (Task 6, `ClockStopwatchTests.wholeMilliseconds`) passed when first run. Extra tests: `nonHTTPResponseIsUnknown`, `requestDelayIsReadPerRequest`, `NetworkLoggerTests.requestIDsAreShortAndUnique`, and `AppErrorTests` (`httpStatus`, distinct messages, the spec's offline copy) as its own suite. The no-cache tests were also mutation-checked: removing the three cache settings made `requestUsesNoCache` and `buildsRequestFromTarget` fail.
- Task 3: the JSON fixture lives in `MerchantCatalogTests/Support/ProductJSON.swift`. Image URLs must be absolute `http(s)` (`"not a url"` is dropped). Extra tests: `missingBrandIsNil`, `missingAvailabilityIsNil`, `missingImagesAndThumbnail`.
- Task 5: the new rows went into a new suite, `CatalogAnalyticsEventTests`, with an explicitly typed case list; extending the existing literal made the type checker time out.
- Task 6: `CatalogFooter` lives in `CatalogPhase.swift`. Extra tests: `unexpectedErrorsAreUnknown`, `retryShowsSkeletonWhileLoading` (also checks that `start()` during a retry doesn't request again). Task 7 added `SpyAnalytics.reset()`.
- Tasks 7–8: extra tests `itemAppearedBeforeContentDoesNothing`, `refreshKeepsContentVisibleWhileLoading`, `refreshToNoProductsShowsEmpty`.
- Task 9: first implemented with `AppTabView` owning the catalog view model (`CatalogConfigurator.makeViewModel(from:)`) and reporting tab visibility from its root `onChange`. **The developer rejected this at the review gate** (`AppTabView` must not own a feature's view model), so `8dd6d5a` restored the planned shape: `CatalogConfigurator.make(from:isTabSelected:)` returns `CatalogView`, which owns its view model in `@State` and calls `catalogBecameVisible()` from `.onChange(of: isTabSelected, initial: true)`. Also added `DesignSystem/Components/ErrorBanner.swift` (the refresh banner).
- Task 10: `URLSessionAPIClient.delay` is internal (read-only) so `AppContextRegistrationTests.slowNetworkSettingReachesTheAPIClient` can check the shared wiring; that test passed when first run (the wiring already existed). Extra test: `slowNetworkToggleStartsFromTheSetting`.
