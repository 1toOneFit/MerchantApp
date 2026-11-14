# S7 change request — list summaries, details fetched on open (D-81)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Design

**Intent (developer, 2026-11-14):** the list should download only what the list shows; full product details are fetched when a product is opened, because most listed products are never opened.

**Verified API facts** (2026-11-14, `curl` against dummyjson.com): `select=title,price,thumbnail,rating,category` works on `/products` and `/products/search`, with `sortBy`/`order` and `limit`/`skip` (`total`, `skip` and order unchanged); `id` is always included; an unknown field name is silently ignored. One sample page of 20: 30.6 KB → 3.8 KB raw, 5.8 KB → 0.9 KB gzip; `/products/2` 0.75 KB gzip (single samples, not benchmarks).

**Goals:** list and search pages request only `id, title, price, thumbnail, rating, category`; opening details from the catalog or search always fetches `/products/{id}`; the screen never shows a partial product as if it were complete. **Non-goals:** caching (D-10), prefetching details, changing the Saved snapshot's fields. **Anti-goal:** a list item must not be decodable into the full `Product` (every detail field is optional, so a summary would silently look like a product without brand, images or reviews and details would hide those sections).

**Approaches considered:** (1) a separate `ProductSummary` type for list items (chosen: the type says what the list has); (2) keep `Product` and decode the slim response into it (rejected: the anti-goal above); (3) keep full list responses and only refetch on open (rejected: doesn't reduce the list download, which is the point).

**Decided with the developer (2026-11-14):**
- Loading: the header (title, category, rating, price) shows at once from the list item with "Loading details…" (replaced by a gallery skeleton in a follow-up, 2026-11-14); gallery, At a Glance and the sections appear when `/products/{id}` arrives.
- Failure: the header stays with a "Couldn't load details" banner and Retry (offline, timeout, server); 404 → "This product is no longer available." without Retry. Details from Saved keep their wording ("Couldn't refresh — showing saved info").
- `product_details_viewed` for catalog/search fires **after the fetch**, with all properties (`content_origin: network`); none if the fetch fails or the user leaves first. `product_details_load_failed` covers catalog/search too (`showing_snapshot: false`).
- Lands on the S7 branch as a change request at the gate (D-81).

**Agent's calls (open to the developer's override):**
- Details from **Saved** keep `product_details_viewed` at the first appearance with `content_origin: snapshot` (D-63): the snapshot is real content shown offline, and `saved_product_revisited` is derived from this event (D-64), so offline revisits keep counting. The `list` value of `content_origin` is removed (no event is sent from list data any more).
- `ProductSummary { id, title, price, thumbnailURL, rating, category }` (= the Saved snapshot's fields without `savedAt`); `SavedProduct` gains `init(_ summary:savedAt:)` and `summary`; `Product.summary`; `ProductSummary.displayProduct` (moved from `SavedProduct`) is what details show before the fetch, as the snapshot does today.
- `ProductsTarget.list`/`.search` append `select=title,price,thumbnail,rating,category` (one constant, exact value tested, since a typo would be ignored by the API).
- The details view model fetches on every `start()` while `idle` (both routes); Retry and cancellation unchanged. The gallery appears only after the fetch (the thumbnail is never a gallery image, D-67).

## Tasks

- [x] **Task 1 — summary type and slim list requests.** Tests first: `ProductsTargetTests` (`select` exact value on list and search, absent on detail); `ProductDTOTests` (a slim item decodes to `ProductSummary`; page of summaries); `LiveProductRepositoryTests` (pages return summaries). Implement `Shared/Products/Domain/ProductSummary.swift`, `ProductSummaryDTO`, `ProductPage.products: [ProductSummary]`, `ProductRepository.products/search` → summaries; `Product.summary`. Update `FakeProductRepository`, `ProductFixtures` (`makeSummary`), catalog code and tests (`CatalogListState`, `ProductCardModel(product: ProductSummary, …)`, `CatalogViewModel`), `SavedProduct`/`SavedProductsStore.save` from a summary, `ProductDetailRoute.list(ProductSummary, source:)`.
- [x] **Task 2 — details fetch for every route.** Tests first in `ProductDetailViewModelTests`: list route starts with the summary's display product and `loading`; success shows the full product; failure keeps the header (`failed`), 404 → `unavailable`; Retry; cancellation applies nothing; `product_details_viewed` (catalog/search) only after success, once, with availability/has_discount/image_count and `content_origin: network`; none after a failure or cancellation; `product_details_load_failed` with `showing_snapshot: false`. Saved tests unchanged. Implement in `ProductDetailViewModel`; view: "Loading details…" and "Couldn't load details" copy for list routes.
- [x] **Task 3 — analytics and docs (same commit as the analytics change).** Analytics.md (`content_origin` `network` | `snapshot`, trigger timing, load-failed sources), `AnalyticsEvent` value; ProductSpecification § 4.1, § 4.3 (AC-D1 reworded: the header without a spinner, the rest after the fetch), Networking.md (A7 rewritten + new `select` fact), Architecture (§ 2, § 5, § 7), D-81 (D-57, D-63 updated), README, AILog, review log with manual checks.
- [x] **Task 4 — verify:** clean Debug + Release builds 0 warnings, full `xcodebuild test`, `git diff --check`.

## Deviations

- Tasks 1 and 2 landed in one commit (`7d39542`) with Analytics.md: a commit with summaries but no details fetch would have shown partial details as if complete, and the view event's timing is analytics code that must change with Analytics.md.
- `SavedProduct` no longer has an initializer from `Product`; details save `product.summary`.
