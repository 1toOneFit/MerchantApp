# Product Specification — MerchantCatalog 1.0

**Status:** Approved by the developer (2026-11-13)
**Source:** derived from [MasterSpecification.md](MasterSpecification.md) plus decisions recorded in [ImplementationPlan.md § Decisions](ImplementationPlan.md#decisions). This file is the maintained source of truth for *what* the app does; [Architecture.md](Architecture.md) covers *how*.

## 1. Problem and audience

Merchants who run their business from a phone browse supplier-style catalogs in short sessions: between orders, on the move, often on unreliable networks. They need to:

1. **Discover** relevant products quickly (browse, search, sort).
2. **Evaluate** a product from factual attributes without reading raw data.
3. **Save** promising options.
4. **Revisit** them in a later session.

MerchantCatalog is the first version of that catalog, built on the public DummyJSON Products API. Prices, stock, shipping and return terms are **demo content from a mock API** and are presented as such; the app makes no claim that they represent a real commercial platform.

## 2. Scope of release 1.0

| Area | In scope |
|---|---|
| Catalog | 2-column product grid, server pagination, load-more feedback, pull-to-refresh, all loading/empty/error states |
| Search & sort | Server-side keyword search with debounce and stale-response protection; server-side sort (price ↑, price ↓, rating ↓) in browse and search |
| Details | Gallery, factual "At a Glance" summary, sectioned attributes, recent reviews, save/unsave |
| Saved | Persisted snapshots, Saved tab, sync across screens, path back to details |
| Resilience | Retry everywhere, non-blocking refresh, image placeholders/failures, basic accessibility |
| Analytics | Typed event taxonomy, user properties, anonymous installation ID, debug event viewer |
| Experiment | `product_card_density_v1` — rating on catalog card (see [Experiments.md](Experiments.md)) |
| Observability | Structured `os.Logger` diagnostics, DEBUG-only diagnostics panel |

Out of scope: see [§ 8 Deliberate exclusions](#8-deliberate-exclusions).

## 3. Navigation

- Two tabs: **Catalog** and **Saved**. The Saved tab shows a badge with the saved count when > 0.
- Each tab owns its own navigation stack, so the tab bar stays visible on push and each tab keeps its own back stack and scroll position.
- Product details are pushed from the Catalog grid, search results, or the Saved list.
- DEBUG builds only: a toolbar button on the Catalog tab opens the **Diagnostics** sheet (analytics event log, user properties, experiment override, slow-network toggle, recent logs, reset installation ID).

## 4. Feature behavior and acceptance criteria

### 4.1 Catalog (browse)

**Card content** — identical in all experiment arms except the rating (see [Experiments.md](Experiments.md)):

| Element | Control | Treatment |
|---|---|---|
| Product image (thumbnail) | ✓ | ✓ |
| Title (max 2 lines) | ✓ | ✓ |
| Price | ✓ | ✓ |
| Save/unsave button | ✓ | ✓ |
| Rating (★ 4.6) | — | ✓ |

Category, brand, discount and availability are deliberately **not** on the card, to keep the experiment's single variable clean; they appear on the details screen.

**Behavior**
- First page loads on first display (20 items). The next page is requested when the user scrolls within ~5 items of the end. Only one page request is in flight at a time. Items are de-duplicated by `id` when appended.
- End of catalog: once `skip + limit >= total`, no further requests; a quiet "You've reached the end" footer.
- Pull-to-refresh reloads page 1 of the current query (browse or search, current sort) **without clearing visible content**. On failure, content stays and a non-blocking error banner appears.
- Returning from details preserves the scroll position, loaded pages, search text and sort.

**States** (each must be visually distinct):

| State | When | UI |
|---|---|---|
| Initial loading | No content yet, first page in flight | Skeleton grid placeholders |
| Content | ≥ 1 item | Grid |
| Loading more | Page ≥ 2 in flight | Spinner footer under grid |
| Load-more failed | Page ≥ 2 failed | Inline footer with message + **Retry** (content stays) |
| Refreshing | Pull-to-refresh in flight | System refresh control; content stays |
| Empty | Successful response, 0 items (browse) | Empty-state message + **Reload** |
| No results | Successful search, 0 items | "No products match "…"" + **Clear search** |
| Failed (no content) | First page failed | Full-screen error, reason-specific message (offline / timeout / server), **Retry** |

**Acceptance criteria**
- AC-C1 Launch → skeleton → grid of 20 products without user action.
- AC-C2 Scrolling to the end loads pages until all 194 demo products are shown; no duplicates; no further requests after the last page.
- AC-C3 With the network off, launch shows the offline error with Retry; turning the network on and tapping Retry loads the grid.
- AC-C4 A failed page-2 request keeps page 1 visible and shows the inline retry footer; retry appends page 2.
- AC-C5 Pull-to-refresh never blanks the grid.
- AC-C6 Opening details and going back restores the exact scroll position and state.

### 4.2 Search and sort

**Search**
- `.searchable` field at the top of the Catalog tab, prompt "Search products", always visible under an inline "Catalog" title (D-47).
- Requests start **300 ms after the last keystroke** (debounce). Leading/trailing whitespace is trimmed; an empty query, or **Cancel** on the search field, returns to browse at once. An edit that leaves the trimmed query unchanged (e.g. a trailing space) sends nothing.
- While the user types, the list on screen stays; once the request starts, the results area shows the skeleton until the results arrive (D-50).
- A new query cancels the in-flight one; a response is applied **only if it belongs to the latest query** (stale-response protection, even if cancellation loses a race).
- Search uses the server endpoint (`/products/search`) with the current sort and pagination — verified to work together, see [Networking.md § API facts](Networking.md#1-verified-api-facts).
- No results: "No products match "…"" with a **Clear search** action.
- Clearing search restores the previous browse list (pages, sort, scroll position) from memory without refetching: the browse grid stays loaded, hidden, under the search results (D-47).
- A failed search shows the full-screen error with **Retry**; pull-to-refresh and loading more work as in browse.

**Sort**
- Options: **Default** (the API's default order, by product id — not a curated ranking), **Price: Low to High**, **Price: High to Low**, **Rating: High to Low**.
- The control is a menu at the toolbar's leading edge. Its label always shows the current sort in short form ("Default", "Lowest price", "Highest price", "Top rated"); the menu lists the options above and marks the current one (D-44).
- Changing sort reloads page 1 server-side for the current mode (browse or search) and scrolls to top: the skeleton shows until the new order arrives, and a failure shows the full-screen error with Retry (D-45). The app **never sorts locally**, so ordering is always across the whole catalog/result set, never just the loaded page.
- A search starts in the sort on screen. A sort change while searching applies to the search only; clearing returns to the browse list in its own sort (D-46, AC-S4). The sort is not persisted across launches (deliberate: avoid surprising state on a new session).

**Acceptance criteria**
- AC-S1 Typing "phone" quickly sends at most one request after typing stops.
- AC-S2 A slow response for an earlier query never replaces results for a later query.
- AC-S3 Search + sort + pagination returns correctly ordered results across pages.
- AC-S4 Clearing search returns to the exact previous browse state.
- AC-S5 A query with no matches shows the no-results state and a working clear action.

### 4.3 Product details

Content renders **immediately** from the product already loaded in the list (the list endpoint returns full product objects). When opened from Saved, the screen shows the saved snapshot immediately and fetches `/products/{id}` for fresh data; if that fetch fails, the snapshot stays visible with a "Couldn't refresh — showing saved info" banner and Retry.

**Layout (top to bottom)**
1. **Gallery** — paged images (1–6 per product; page indicator hidden when there is one image), loading placeholder and failure state per image; each image loads only while its page is on screen. A product without images has no gallery.
2. **Header** — title, brand (when present; 92 of 194 demo products have none), category.
3. **At a Glance** — compact factual chips, only for fields that exist: rating (without a review count: the aggregate rating isn't based on the 3 returned reviews, § 6, D-55), availability (+ stock units), minimum order quantity, shipping information, return policy, warranty.
4. **Pricing** — price; discount percentage as provided by the API, with up to 2 fraction digits, e.g. "−7.17%", shown only when greater than 0 (see [§ 6 Data semantics](#6-data-semantics), D-58).
5. **Overview** — description, tags.
6. **Product information** — SKU, brand, category, weight, dimensions, warranty. Weight and dimensions are shown as the API gives them, without units, because the API states none ([Networking.md A14](Networking.md#1-verified-api-facts), D-58).
7. **Shipping & availability** — availability status, stock, shipping information, minimum order quantity, return policy.
8. **Reviews** — "Recent reviews" (the API returns 3 per product): rating, comment, reviewer name, date. Reviewer email is never displayed or logged.

Save/unsave is a toolbar button (a bookmark); state stays consistent with the grid and Saved tab.

**Opened from Saved (as built, S5):** the snapshot shows title, category, rating and price at once, labeled "Saved information · Saved 3 Nov", without a gallery (the gallery never shows the card thumbnail) while "Updating…" fetches `/products/{id}`. Success replaces it with the full product; if the price differs from the snapshot's, Pricing adds "Price changed since you saved it" and "Price when saved: $9.99". A failure keeps the snapshot with "Couldn't refresh — showing saved info" and **Retry**. A 404 keeps the snapshot with "This product is no longer available." and no Retry (the product can still be unsaved). The stored snapshot is never overwritten by fresh data, so "price when saved" stays the price when saved (D-67).

Details open from a card tap in the browse grid or search results, on the Catalog tab's stack. Going back shows the catalog exactly as it was: scroll position, loaded pages, search text, results and sort (AC-C6); a search stays active even if the system deactivated the search field for the push (D-54).

**Insight rule:** only facts present in the data. No invented score, margin, recommendation or "best seller" claim.

**Acceptance criteria**
- AC-D1 Opening a product from the grid shows full content without a spinner.
- AC-D2 Sections with no data are omitted, never shown empty.
- AC-D3 Save on details updates the grid card and Saved tab immediately.
- AC-D4 Opening from Saved while offline shows the snapshot plus the refresh-failed banner.

### 4.4 Saved products

- Save/unsave from the catalog card (a bookmark button over the thumbnail's top-trailing corner, D-60), details toolbar, and swipe-to-delete in the Saved list.
- Persisted locally as **snapshots**: `id, title, thumbnailURL, price, rating, category, savedAt`. Snapshots let the Saved tab render instantly and offline; they are labeled as **saved information**, e.g. "Price when saved: $9.99 · Saved 3 Nov".
- Saved data is treated as a durable *selection*, not as current truth: details always refetch, and if the fresh price differs from the snapshot the details screen shows "Price changed since you saved it" (factual, no judgement).
- Saved row: thumbnail, title, price when saved, saved date. No rating (identical in both experiment arms).
- Order: most recently saved first.
- Empty state: explanation + **Browse catalog** button that switches to the Catalog tab (D-61).
- Survives relaunch; a corrupt store file is moved aside, logged, and the app starts with an empty list rather than crashing. A file with an unknown format version (e.g. from a newer build) is left in place, logged, and the app starts empty; the next save overwrites it (D-65).

**Acceptance criteria**
- AC-V1 Saving from any surface updates all surfaces (card icon, details toolbar, Saved list, tab badge) at once.
- AC-V2 Saved items survive app termination and relaunch.
- AC-V3 Saved tab works offline using snapshots.
- AC-V4 Unsave via swipe removes the item and updates the grid card.

### 4.5 Resilience and accessibility

- Error messages are specific and actionable: offline ("You're offline. Check your connection and try again."), timeout, server error, unexpected data.
- Offline messaging appears **only** where saved content really exists (Saved snapshots — the user's data, not a cache). The app does no caching, so the catalog needs a connection (see [Networking.md § 3](Networking.md#3-caching--deliberately-not-implemented)).
- Images load **only while visible**: loading starts when a cell appears, and an in-flight load stops when the cell disappears. Placeholder while loading, neutral icon on failure, retried on the next appearance. No image cache, so a scrolled-back image downloads again (see [Networking.md § 4](Networking.md#4-image-loading)).
- Dynamic Type supported on all text (cards allow 2-line titles, grid stays usable at accessibility sizes by switching to 1 column at AX sizes).
- VoiceOver: each card reads as one element: "Title, price[, rating], saved/not saved" with a custom action for save/unsave. Buttons have labels; images are decorative unless in the gallery.
- Tap targets ≥ 44 × 44 pt. Dark mode supported via system colors.

## 5. Analytics and experiment

Defined in [Analytics.md](Analytics.md) (event taxonomy, user properties, installation ID) and [Experiments.md](Experiments.md) (`product_card_density_v1`). No real analytics backend: events go to structured logs and the DEBUG Diagnostics panel.

**How we'd know it works for merchants** (once real traffic exists; no metric is pre-declared as a North Star):

| Journey step | Candidate signal (from the taxonomy) |
|---|---|
| Discover | Searches with ≥ 1 result that lead to `product_selected`; zero-result search rate; sort usage |
| Evaluate | `product_details_viewed` per session; gallery engagement |
| Save | `product_saved` per details view; unsave-within-session rate |
| Revisit | `saved_product_revisited` in a later session; returning sessions with Saved tab views |
| Reliability | `catalog_load_failed` / `catalog_page_failed` rates; retry success |

## 6. Data semantics

- **Price & discount:** the API supplies `price` and `discountPercentage` without documenting whether `price` is before or after discount. The app shows `price` as "Price" and the discount as "−7%" information. **No discounted price is computed**, to avoid presenting an invented number. *(Decision — see ImplementationPlan D-11.)*
- **Rating:** the aggregate `rating` field (always present, 2.51–4.99 in demo data). It is not the average of the 3 returned reviews and is never recomputed.
- **Reviews:** the API returns exactly 3 per product → labeled "Recent reviews", not "All reviews".
- **Currency:** demo values formatted as USD with the device locale's number formatting.

## 7. Non-functional requirements

- Builds and runs in the iOS Simulator with no setup beyond opening the project (no keys, no package resolution).
- No third-party dependencies in 1.0.
- Unit tests deterministic, no live network; no UI snapshot tests.
- Main thread never blocks on networking, JSON decoding or file I/O (image loading and decoding are handled by `AsyncImage`).
- No HTTP or custom caching ([Networking.md § 3](Networking.md#3-caching--deliberately-not-implemented)).

## 8. Deliberate exclusions

Login/accounts, cart/checkout, product editing, orders/inventory management, remote sync of saved items, personalization or AI recommendations, remote experimentation/feature-flag service, production analytics backend or dashboards, advanced filtering (category/price range), response or image caching, offline catalog persistence, localization beyond English, iPad-specific layouts, UI snapshot tests.
