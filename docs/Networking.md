# Networking, Caching and Images

**Status:** Approved by the developer (2026-11-13). Section 1 is **verified**. Section 4 contains an **expectation** the developer verifies manually (the agent does not run the Simulator).

Legend: ✅ verified (with date and method) · 🔍 expectation, not yet verified.

## 1. Verified API facts

Method: `curl` against `https://dummyjson.com` on 2026-11-13. Re-verify if behavior seems different.

| # | Fact | Consequence |
|---|---|---|
| A1 ✅ | The catalog has **194** products. List responses are `{ products, total, skip, limit }`. | Pagination ends when `skip + limit >= total`. |
| A2 ✅ | `GET /products?sortBy=price&order=asc&limit=10&skip=10` continues the global order from page 1: page 1 ends at 2.49, page 2 starts at 2.49 with a different id. Tie order was identical across 3 runs. | Sorting is server-side over the whole catalog, so the app never sorts locally. Still de-duplicate by `id` defensively. |
| A3 ✅ | `GET /products/search?q=phone&sortBy=price&order=desc&limit=5&skip=5` → `total: 23`, correctly ordered across pages. `sortBy=rating&order=desc` also works for search. | Search, sort and pagination can all run server-side together. |
| A4 ✅ | An unknown `sortBy` (e.g. `foo`) is **silently ignored**: HTTP 200, default order. | Sort is a closed enum, and endpoint tests assert the exact query items. |
| A5 ✅ | Search with no matches → `{"products":[],"total":0,"skip":0,"limit":0}`. | The no-results state is keyed on `total == 0`. |
| A6 ✅ | An unknown id → HTTP **404** `{"message":"Product with id '99999' not found"}`. | Map to `AppError.notFound`; details opened from Saved show "no longer available". |
| A7 ✅ | List items contain the **full** product object (description, images, reviews, shipping, etc.). | Details render immediately from list data. `GET /products/{id}` is only needed when refreshing details opened from Saved. |
| A8 ✅ | `?delay=<ms>` delays the response (1500 → ~1.6 s total). | A DEBUG "slow network" toggle appends `delay` to every request. |
| A9 ✅ | Response header `x-ratelimit-limit: 100` (plus `-remaining`, `-reset`). | Debounce search, never request per keystroke, keep one page request in flight. |
| A10 ✅ | Every product has `rating` (2.51–4.99) and exactly **3** reviews. 92 of 194 have no `brand`. Each has 1–6 images. `availabilityStatus` ∈ {In Stock, Low Stock, Out of Stock}. | `brand` is optional, reviews are labelled "Recent reviews", and the gallery handles a single image. |
| A11 ✅ | Product JSON: `ETag` (weak) but **no** `Cache-Control`, `Expires` or `Last-Modified`. `If-None-Match` → `304`. | See § 3. |
| A12 ✅ | Images (`cdn.dummyjson.com`, `.webp`, ~10 KB thumbnails): `Cache-Control: public, max-age=0, no-store`. | See § 3 and § 4. |
| A13 ✅ | A `+` in the `q` value is decoded as a **space**: `q=iphone+charger` and `q=iphone%20charger` both → `total: 1`, `q=iphone%2Bcharger` → `total: 0` (curl, 2026-11-13). | The client sends `+` as `%2B` (D-51); `URLComponents` leaves `+` unencoded (checked with a Swift script, 2026-11-13). |
| A14 ✅ | Details fields over all 194 products (curl `/products?limit=0`, 2026-11-13): `weight` is an integer 1–10 and `dimensions` (`width`, `height`, `depth`) are decimals, both **without units**; `discountPercentage` is 0.04–19.61 (none is 0, 7 are under 1 %); `availabilityStatus` and `stock` are independent (10 "In Stock" products have stock ≤ 10, the 4 "Out of Stock" ones have 0); `minimumOrderQuantity` 1–50; reviews carry `rating` 1–5, `comment`, `date` (ISO 8601 with milliseconds), `reviewerName` and `reviewerEmail`; `description` and `tags` are never empty. | Details show numbers as given, without invented units (D-58); the discount row depends on `> 0`, not on rounding; `reviewerEmail` is not decoded. |

## 2. Network layer (protocol-first)

Consumers depend on a protocol, never on `URLSession`:

```swift
protocol APIClientType: Sendable {
    func request<Response: Decodable & Sendable>(_ target: some TargetType) async throws -> Response
}

final class URLSessionAPIClient: APIClientType { … }   // the only type that touches URLSession
```

Repositories (`LiveProductRepository`) receive an `APIClientType`. Swapping the transport (another HTTP stack, a mock server, a recording client) means writing a new conforming type and registering it. The protocol, repositories and view models don't change. Unit tests use `FakeAPIClient` (repository tests) and `StubURLProtocol` (tests of `URLSessionAPIClient` itself).

**Endpoints** (`ProductsTarget`, Moya-style):

```swift
enum ProductsTarget: TargetType {
    case list(skip: Int, limit: Int, sort: ProductSort)
    case search(query: String, skip: Int, limit: Int, sort: ProductSort)
    case detail(id: Int)
}

protocol TargetType: Sendable {
    var baseURL: URL { get }                 // default: APIConfig.baseURL
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var timeout: TimeInterval { get }        // default 15 s
}
```

`ProductSort.defaultOrder` sends no `sortBy` (the API's default order, by id). The other cases map to `sortBy=price&order=asc`, `sortBy=price&order=desc` and `sortBy=rating&order=desc`.

**`URLSessionAPIClient`** builds a `URLRequest` from a target, runs it with `URLSession.data(for:)`, validates the status, decodes off the main actor, and maps failures:

| Failure | `AppError` | User message |
|---|---|---|
| `URLError.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed` | `.offline` | "You're offline…" |
| `URLError.timedOut` | `.timeout` | "This is taking too long…" |
| HTTP 404 | `.notFound` | "This product is no longer available." |
| HTTP 429 | `.rateLimited` | "Too many requests. Try again in a moment." |
| HTTP 5xx / other non-2xx | `.server(status:)` | "Something went wrong on our side…" |
| Decoding error | `.decoding` | "We received unexpected data…" |
| `URLError.cancelled` / `CancellationError` | rethrown as `CancellationError` | none; callers treat it as "no state change" |

The client does no automatic retries. Retries are user-initiated, which keeps the user in control and respects the rate limit. Cancelling the calling Swift task cancels the underlying `URLSession` task (async API behavior).

Codes and statuses outside this table (e.g. `URLError.cannotFindHost`, a 400, a non-HTTP response) map to `.unknown` / `.server(status:)` (D-43).

**Request logging** (`network` category): method, URL with the `q` value redacted (`q=<private>`), a short request id, status, latency, response size, cancellation and errors. Errors are logged as a code or category (`URLError -1009`, `DecodingError.typeMismatch at price`), never as their description, which can include the request URL.

**As built (S2):** `URLSessionAPIClient.makeRequest(for:delay:)` builds the request (base URL + path + query items, method, headers, timeout, `.reloadIgnoringLocalCacheData`) and appends `delay=<ms>` when the DEBUG slow-network toggle is on: a `RequestDelay` shared with `SlowNetworkSetting` and read on every request (D-42). `request(_:)` is `@concurrent`. `URLSessionAPIClientTests` cover each row of the table with `StubURLProtocol`, plus the no-cache configuration and cancellation. `ProductsTarget` has `.list`, (S3) `.search` and (S5) `.detail(id:)`, behind `ProductRepository.product(id:)`; only details opened from Saved request it (list items are full products, A7, D-57). **S3:** after setting the query items, `makeRequest` replaces `+` with `%2B` in the percent-encoded query (A13, D-51); `buildsSearchRequestWithSortAndPage` and `searchQueryIsPercentEncoded` cover it.

## 3. Caching — deliberately not implemented

**Decision (developer, 2026-11-13): no HTTP caching and no custom caching in 1.0.**

- **`URLSession`/`URLCache` caching gives no practical benefit with these headers.** Product JSON has an `ETag` but no freshness information (`Cache-Control: max-age`, `Expires`, `Last-Modified`). At best a stored copy could be revalidated on every request, which saves some bytes on a 304 but no round trip and no offline use. Images are sent with `no-store`, which forbids storing them at all.
- **A custom caching layer** (an app-level response cache, or an image memory/disk cache) is too much machinery for this assignment's scope.
- **Implementation:** `URLSessionAPIClient` uses its own `URLSessionConfiguration` with `urlCache = nil` and `requestCachePolicy = .reloadIgnoringLocalCacheData`. That makes the behavior explicit and predictable: every request, including pull-to-refresh, goes to the network.
- **Not verified:** whether `URLCache` would store the ETag-only responses, or whether it adds `If-None-Match` automatically. These questions were dropped together with caching; no claim is made either way.
- **Not a cache:** Saved-product snapshots ([ProductSpecification § 4.4](ProductSpecification.md#44-saved-products)) are the user's saved selections, persisted on purpose. They are labelled as saved information and refreshed when opened.
- **Consequence:** the catalog requires a network connection, and scrolled-back thumbnails are downloaded again (~10 KB each).

## 4. Image loading

Images use SwiftUI **`AsyncImage`**. There is no custom image loader and no image cache (see § 3).

### Requirement

Image loading **starts when a cell appears** and **stops when the cell disappears** if the load is still in progress.

### Design: visibility-gated `AsyncImage`

Lazy grids create cells on demand but may keep an off-screen cell's view alive, so `AsyncImage` alone isn't guaranteed to stop work when a cell scrolls away. `ProductImageView` makes the lifecycle explicit:

```swift
struct ProductImageView: View {
    let url: URL?
    @State private var isVisible = false

    var body: some View {
        ZStack {
            placeholder                          // always present: fixed size, no layout jump
            if isVisible, let url {
                AsyncImage(url: url) { phase in … }   // empty → placeholder, success → image, failure → icon
                    .id(url)                          // new URL → new load
            }
        }
        .onAppear { isVisible = true }               // start loading
        .onDisappear { isVisible = false }           // remove AsyncImage → its in-flight load is torn down
    }
}
```

- **Appear:** `isVisible = true` inserts `AsyncImage`, which starts the request.
- **Disappear:** `isVisible = false` removes `AsyncImage` from the hierarchy. SwiftUI ends the work of removed views, so an in-flight load stops and its result can never land in a cell that now shows another product.
- **Reuse / identity change:** `.id(url)` forces a fresh `AsyncImage` when the URL changes.
- **Failure:** a neutral icon. Because the view is recreated on the next appearance, scrolling back retries automatically.
- **Gallery:** the same component per page, so only visible pages load.
- **Concurrency:** there is no app-level `Task`; loading and decoding are managed by `AsyncImage`.

### Verification

- 🔍 **Expectation:** removing an `AsyncImage` from the hierarchy cancels its in-flight request. Apple documents automatic cancellation for `.task`, but not explicitly for `AsyncImage`, so this is verified manually by the developer, not asserted.
  - **Manual check:** slow image downloads with macOS Network Link Conditioner (e.g. the "3G" profile); the DEBUG `delay` toggle affects only API requests. Scroll fast through the grid and watch a proxy (Proxyman/Charles) or Instruments' network template: requests for cells that left the screen should end as cancelled. Record the date, method and result here.
  - **Status:** `ProductImageView` is implemented as designed above (S2). The manual check is pending (handed to the developer at the S2 review gate); no result is claimed yet.
- Unit tests cover what is controllable: card and gallery presentation models expose the right URLs (thumbnail for cards, full images for the gallery, `nil` → placeholder only). `AsyncImage`'s network lifecycle can't be proven in unit tests and isn't claimed to be.

### Known limitations (accepted)

- No de-duplication: two visible views with the same URL load it twice (rare in this UI).
- No control over decoding or downsampling: full gallery images are decoded at full size by `AsyncImage`.
- Re-download on every reappearance (no cache).
