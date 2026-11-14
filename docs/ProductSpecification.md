# Product Specification — MerchantCatalog 1.0

**Status:** Approved by the developer (2026-11-13); § 4.1, § 4.3, § 4.5 and the new § 4.6 updated for S8 (Needs attention, 2026-11-14)
**Source:** derived from [MasterSpecification.md](MasterSpecification.md) plus decisions recorded in [ImplementationPlan.md § Decisions](ImplementationPlan.md#decisions). This file is the maintained source of truth for *what* the app does; [Architecture.md](Architecture.md) covers *how*.

## 1. Problem and audience

Merchants who run their business from a phone browse supplier-style catalogs in short sessions: between orders, on the move, often on unreliable networks. They need to:

1. **Discover** relevant products quickly (browse, search, sort).
2. **Evaluate** a product from factual attributes without reading raw data.
3. **Save** promising options.
4. **Revisit** them in a later session.

Since S8 the catalog's first question is **"Which products need my attention?"**: stock status is on every card, a Needs attention scope lists the low and out-of-stock products, and details lead with stock (§ 4.6).

MerchantCatalog is the first version of that catalog, built on the public DummyJSON Products API. Prices, stock, shipping and return terms are **demo content from a mock API** and are presented as such; the app makes no claim that they represent a real commercial platform.

## 2. Scope of release 1.0

| Area | In scope |
|---|---|
| Catalog | 2-column product grid, server pagination, load-more feedback, pull-to-refresh, all loading/empty/error states; stock status on cards and a Needs attention scope (S8, § 4.6) |
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
| Stock status: "Out of stock", "Low stock · 4 left", "In stock" (S8, D-86) | ✓ | ✓ |
| Save/unsave button | ✓ | ✓ |
| Rating: the product's API rating, one decimal (★ + e.g. 4.96 → 5.0, D-71) | — | ✓ |

Category, brand and discount are deliberately **not** on the card, to keep the experiment's single variable clean; they appear on the details screen. Stock status is on the card in **both** arms since S8 (D-86, supersedes D-12): it answers the catalog's main question, and the rating stays the only difference between the arms (Experiments.md notes the layout change).

**Stock status (S8, D-84):** one policy on the product's `stock`, in `StockStatus`: 0 → **Out of stock** (red), 1–10 → **Low stock** with the count ("Low stock · 4 left", orange), more than 10 → **In stock** (secondary text, green symbol). A product whose stock is unknown shows no status (an invisible row keeps the card height). The same wording is used on cards and the details badge; on screen the count is set off with a middle dot, "Low stock · 4 left", and VoiceOver reads it with a comma, **"Low stock, 4 left"** (the canonical spoken form, `StockLabel.accessibilityText`). The API's own `availabilityStatus` is not used: list pages don't load it, and it disagrees with `stock` for some demo products ([Networking.md A16](Networking.md#1-verified-api-facts)).

**Rating on the card (as built, S6):** under the price, a filled star and the product's API rating formatted to one decimal (e.g. 4.94 → "★ 4.9", 4.96 → "★ 5.0", D-71), in the secondary color. The control card lays out the same row, invisible, so both arms have the same card height (D-21). VoiceOver reads the same value in the card's label, e.g. "rated 4.9 of 5" (§ 4.5). The variant is the installation's assignment for the launch (D-69).

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
- The keyboard can be put away without ending the search: starting to scroll the grid (either direction) or the keyboard's **Search** key dismisses it with an animation; the query, results and sort stay, and tapping the field brings it back (D-79). Only **Cancel** ends the search.
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

List pages carry only a summary of each product (title, price, thumbnail, rating, category); details open with just the product's id and always load the full product from `/products/{id}` (D-81, D-83). Until it arrives, the whole screen is a skeleton: the gallery's square with a spinner and the layout of every part (header, chips, sections) as pulsing placeholders; no list data is shown. Then the full product shows at once. From the catalog or search, a failure is a full-screen error with **Retry** (offline, timeout or server wording); a 404 says the product is no longer available, without Retry. From Saved, a failure shows the saved snapshot instead (found in Saved by id) with a "Couldn't refresh — showing saved info" banner and Retry.

**Layout (top to bottom)**
1. **Gallery** — paged images (1–6 per product; page indicator hidden when there is one image), loading placeholder and failure state per image; each image loads only while its page is on screen. A product without images has no gallery.
2. **Header** (S8, D-87) — what a merchant checks first, in this order: title; price; stock status as a colored badge ("Low stock · 4 left", § 4.1 policy; left out when the stock is unknown, e.g. Saved's snapshot); category · brand (brand when present; 92 of 194 demo products have none); rating ("★ 4.94", without a review count: the aggregate rating isn't based on the 3 returned reviews, § 6, D-55).
3. **At a Glance** — compact factual chips, only for fields that exist: minimum order quantity, shipping information, return policy, warranty (rating and availability moved to the header in S8).
4. **Pricing** — discount percentage as provided by the API, with up to 2 fraction digits, e.g. "−7.17%", shown only when greater than 0 (see [§ 6 Data semantics](#6-data-semantics), D-58), and the price-changed note from Saved; the section is left out without either (the price is in the header since S8).
5. **Overview** — description, tags.
6. **Product information** — SKU, brand, category, weight, dimensions, warranty. Weight and dimensions are shown as the API gives them, without units, because the API states none ([Networking.md A14](Networking.md#1-verified-api-facts), D-58).
7. **Shipping & availability** — availability status (from the stock, § 4.1 policy), stock units, shipping information, minimum order quantity, return policy.
8. **Reviews** — "Recent reviews" (the API returns 3 per product): rating, comment, reviewer name, date. Reviewer email is never displayed or logged.

Save/unsave is a toolbar button (a bookmark); state stays consistent with the grid and Saved tab. Nothing on details edits, orders or restocks a product (§ 8).

**Opened from Saved (as built, S5; by id since D-83):** the skeleton shows while `/products/{id}` loads, as from the catalog. Success shows the full product; if the price differs from the snapshot's, Pricing adds "Price changed since you saved it" and "Price when saved: $9.99". A failure shows the snapshot (title, category, rating, price, no gallery), labeled "Saved information · Saved 3 Nov", with "Couldn't refresh — showing saved info" and **Retry** ("Updating…" while it retries). A 404 shows the snapshot with "This product is no longer available." and no Retry (the product can still be unsaved). On a slow but not absent connection the snapshot appears only when the request fails (up to the 15 s timeout). The stored snapshot is never overwritten by fresh data, so "price when saved" stays the price when saved (D-67).

Details open from a card tap in the browse grid or search results, on the Catalog tab's stack. Going back shows the catalog exactly as it was: scroll position, loaded pages, search text, results and sort (AC-C6); a search stays active even if the system deactivated the search field for the push (D-54).

**Insight rule:** only facts present in the data. No invented score, margin, recommendation or "best seller" claim.

**Acceptance criteria**
- AC-D1 Opening a product from the grid shows a skeleton, then the full details as soon as `/products/{id}` returns; a failure shows an error with Retry (D-83; before D-81: full content without a request).
- AC-D2 Sections with no data are omitted, never shown empty.
- AC-D3 Save on details updates the grid card and Saved tab immediately.
- AC-D4 Opening from Saved while offline shows the snapshot plus the refresh-failed banner (after the failed request, D-83).

### 4.4 Saved products

- Save/unsave from the catalog card (a bookmark button over the thumbnail's top-trailing corner, D-60), details toolbar, and swipe-to-delete in the Saved list.
- Persisted locally as **snapshots**: the list item's summary (`id, title, thumbnailURL, price, rating, category`, the same data a list hands to details) plus `savedAt` (D-82). The list item's stock is not kept: offline it would read as current (D-89), so Saved's snapshot fallback on details shows no stock status. Snapshots let the Saved tab render instantly and offline; they are labeled as **saved information**, e.g. "Price when saved: $9.99 · Saved 3 Nov".
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
- Images load **only while visible**: loading starts when a cell appears, and an in-flight load is cancelled when the cell disappears, e.g. on fast scrolling (D-78). Placeholder while loading, neutral icon on failure, retried on the next appearance. No image cache, so a scrolled-back image downloads again (see [Networking.md § 4](Networking.md#4-image-loading)).
- Dynamic Type supported on all text (cards allow 2-line titles, grid stays usable at accessibility sizes by switching to 1 column at AX sizes).
- VoiceOver: each card reads as one element: "Title, price[, rating], saved/not saved" with a custom action for save/unsave. Buttons have labels; images are decorative unless in the gallery.
- Tap targets ≥ 44 × 44 pt. Dark mode supported via system colors.

**As built (S7):**
- **Dynamic Type:** all text uses system text styles. The catalog grid and its loading skeleton have two columns up to the largest standard size (xxxLarge) and one column at every accessibility size (AX1–AX5), so titles keep a readable line length (D-75). Card titles keep two lines with reserved space; the rating row keeps cards of equal height at every size.
- **VoiceOver:** each catalog card is one element, e.g. "Essence Mascara Lash Princess, $9.99, In stock, rated 2.6 of 5, not saved", or for a low-stock product "Volume Mascara, $9.99, Low stock, 4 left, not saved" (the stock status since S8, read after the price in the § 4.1 spoken form; the rating only in the treatment arm), with the button trait (opens details) and a custom action "Save" / "Remove from Saved"; the visible bookmark is not a separate stop (D-60). Saved rows and the details status lines read as one element each.
- **Tap targets:** the card bookmark and the refresh banner's close button have a 44 × 44 pt tappable frame inside the button; standalone bordered buttons (Retry, Reload, Clear search, Browse catalog, the details banner's Retry) use the system's large control size (D-76); toolbar items use the system's sizing.
- **Dark mode:** only system colors, materials and semantic styles (`.primary`, `.secondary`, `.tint`, `.orange`), no fixed colors, so every screen follows the system appearance. Checked manually, not by tests.

### 4.6 Needs attention (S8)

The catalog answers "Which products need my attention?" within the first seconds: low and out-of-stock products, from the data the app already has.

- **Control:** two chips at the top of the grid, **All products** and **Needs attention** with a count (D-85). They apply to the list on screen: the browse catalog, or the results of the current search. The selected chip is filled; both are at least 44 pt tall and stack at large text sizes.
- **What counts:** a loaded product whose stock status (§ 4.1) is Low stock or Out of stock. A product with unknown stock never counts.
- **Count:** the number of such products among the products of the list **loaded so far**; it grows as more pages load (scrolling in All products, or Load more products). It shows once the list has products.
- **Needs attention view:** the same cards, in the server's order (and the current sort), only those products; the footer says what the count is based on — "Based on 20 of 194 products loaded so far." or "Based on all 194 products." — with **Load more products** while more pages exist (spinner while loading, message and Retry on failure). Cards don't load pages automatically in this view. With none to show: "Nothing needs attention" / "None of the loaded products is low or out of stock."
- **Honest limitation:** the API has no inventory endpoint and no stock filter, so the app looks only at the products it loaded; it makes no extra request and doesn't claim a complete count until every page is loaded. A full inventory or ordering flow is out of scope (§ 8).
- Search, sort, pull-to-refresh, pagination, details and saving behave as in All products; switching the scope sends no request and keeps the loaded pages.

**Acceptance criteria**
- AC-A1 After launch, cards show their stock status and the Needs attention chip shows the count of loaded low and out-of-stock products.
- AC-A2 Needs attention shows only low and out-of-stock products; an in-stock product is never included; All products shows every loaded product again.
- AC-A3 Loading another page updates the count and the Needs attention list.
- AC-A4 Details show title, price, stock status, category and rating before the other sections.

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
- UI tests (XCUITest, since S8) run against a fixed, offline fixture (`-ui-testing`, DEBUG builds only, D-88) and find elements by accessibility identifier.
- Main thread never blocks on networking, JSON decoding or file I/O (image download and decoding run off the main actor in `URLSessionImageLoader`, D-78).
- No HTTP or custom caching ([Networking.md § 3](Networking.md#3-caching--deliberately-not-implemented)).

## 8. Deliberate exclusions

Login/accounts, cart/checkout, product editing, orders/inventory management (including restocking, stock alerts or a full-inventory view: S8's Needs attention looks only at loaded products), remote sync of saved items, personalization or AI recommendations, remote experimentation/feature-flag service, production analytics backend or dashboards, advanced filtering (category/price range), response or image caching, offline catalog persistence, localization beyond English, iPad-specific layouts, UI snapshot tests.
