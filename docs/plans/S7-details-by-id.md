# S7 change request — details opened by id, full-screen skeleton (D-83)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Design

**Intent (developer, 2026-11-14):** the details screen shouldn't render pieces of list data (title, rating, price) that are then replaced: that is noise. It opens with just the product's id, shows a skeleton for everything (gallery, header, chips, sections) and shows the full product once `/products/{id}` returns.

**Goals:** one route value for every source: `id + source`; the whole screen is a skeleton until the full product arrives, then everything at once. **Non-goals:** changing list summaries (cards need them, D-81) or the Saved tab's snapshot (rows need it, D-82); caching (D-10). **Anti-goal:** losing offline details from Saved (AC-D4, AC-V3).

**Approaches:** (A, chosen by the developer) id-only route everywhere; details look up the saved snapshot in the store by id, and show it only when the request fails (offline/server/404), with the existing banner; (B) fully uniform, Saved offline shows the same full-screen error (drops AC-D4).

**Behavior:**
- **Every route, online:** full-screen skeleton (the real layout over a placeholder product, `.redacted(reason: .placeholder)`, pulsing like the gallery skeleton, off with Reduce Motion; VoiceOver "Loading product details"), then the full product.
- **Catalog/search, failure:** a full-screen error with Retry (offline/timeout/server copy from `AppError`); 404 → "This product is no longer available." without Retry.
- **Saved, failure:** the saved snapshot with "Saved information · Saved …" and "Couldn't refresh — showing saved info" + Retry; 404 → snapshot + "This product is no longer available." (as today).
- **Price note** (Saved): after a success, "Price changed since you saved it" when the fresh price differs from the snapshot captured when the screen opened (D-67).
- **Toolbar bookmark:** shows the saved state at once; enabled once something can be saved or removed: the full product, the Saved fallback, or an already-saved product (removal never needs data).

**Analytics (agent's call, D-83):** `product_details_viewed` fires when real content first shows, once per push: after a success from any route (`content_origin: network`, all properties); from Saved, the snapshot fallback after a failure also counts (`content_origin: snapshot`, without availability/has_discount/image_count), so offline revisits keep counting (`saved_product_revisited`, D-64). No event while only the skeleton shows or when the user leaves first. `product_details_load_failed`: `showing_snapshot` true for the Saved fallback, false otherwise.

**Data layer:**
- `ProductDetailRoute` becomes `struct { productID: Int; source: ProductSource }` (replaces the D-62 enum and D-82's `route.summary`).
- `CatalogViewModel.cardSelected` and `SavedViewModel.rowSelected` push `ProductDetailRoute(productID:source:)`.
- `ProductDetailViewModel`: `product: Product?` (the full product), `savedSnapshot: SavedProduct?` (from the store at init, Saved source only), phase `loading | loaded | failed(AppError) | unavailable` (renamed from `DetailRefreshState`); `displayedProduct` = the full product, else the Saved fallback's `displayProduct` after a failure, else `nil` (skeleton).
- `ProductSummary.displayProduct` goes (only Saved's fallback needs a display product); `SavedProduct.displayProduct` builds it.
- Repository unchanged (`product(id:)`).

**Trade-off:** from Saved on a bad (not absent) connection, the snapshot appears only when the request fails (up to the 15 s timeout); offline fails at once.

## Tasks

- [x] **Task 1 — route by id.** Tests first: `RouterTests` (route = id + source; log description), `CatalogViewModelSelectionTests` and `SavedViewModelTests` (pushed route). Implement the struct and the two call sites.
- [x] **Task 2 — view model.** Tests first: rewrite `ProductDetailViewModelTests` (catalog/search: skeleton state, load, cancellation, failure → error, 404, Retry, view event after success, gallery, saving disabled/enabled) and `ProductDetailSavedTests` (skeleton first, success with price note, failure → snapshot fallback + event `snapshot` + load_failed `showing_snapshot: true`, 404 fallback, Retry, unsave during fallback). Implement; Analytics.md in the same commit.
- [x] **Task 3 — view.** Full-screen skeleton (placeholder product, redacted, pulse), error state for list routes, Saved fallback with the existing status view, bookmark enabled rule. Build only (no view tests).
- [x] **Task 4 — docs + verify.** ProductSpecification § 4.3/4.4 (AC-D1, AC-D4), Architecture § 7, D-83 (D-62, D-63, D-81, D-82 marked updated), README, AILog, review log with manual checks; clean Debug/Release 0 warnings, full tests.

## Deviations

- Tasks 1–3 landed in one commit (`87222b6`) with Analytics.md: the route change doesn't compile without the view model, and the view event's timing is analytics code.
- `ProductSummary.displayProduct` stays: `SavedProduct.displayProduct` (Saved's fallback) builds on it.
- A cancelled Retry returns to the failure it started from, and from Saved the snapshot stays on screen while a Retry runs ("Updating…"); found while rewriting the Saved tests.
- VoiceOver reads the whole skeleton as one element, "Loading product details" (the gallery skeleton's own label went into it).
