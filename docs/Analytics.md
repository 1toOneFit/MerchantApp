# Analytics — Event Taxonomy and User Properties

**Status:** Approved by the developer (2026-11-13). This file is the **single authoritative taxonomy**. Code and this file must match: `TaxonomyDocumentationTests` fails if an `AnalyticsEvent` case has no matching level-4 heading ``#### `event_name` `` here, or such a heading has no case in code. Each event has a `Status` line: **Planned (S<n>)** until the stage that implements it switches it to **Active** in the same commit as the code; the test compares only Active events with code.

## 1. Principles

- Track **meaningful user actions and outcomes** along Discover → Evaluate → Save → Revisit. Technical per-request detail goes to logs ([Architecture.md § 10](Architecture.md#10-logging-and-observability)).
- One event per meaning. Variations are **properties**, not new event names (e.g. one `product_selected` with `source`, not three "selected" events).
- No events per keystroke, per scroll offset, or per render. Every event below states its deduplication rule.
- No events for UI that doesn't exist.
- Naming: `object_action` in snake_case, past tense where it records something that happened. Property names and enum values are snake_case. Durations are integer milliseconds unless the name says `_s` (seconds) or `_days`.
- Protocol-first: features call only `AnalyticsTracking`. `AnalyticsService` adds the envelope and fans out to every registered `AnalyticsProvider`. No backend in 1.0: providers are `LoggingAnalyticsProvider` (`analytics` log category) and `InMemoryAnalyticsProvider` (DEBUG Diagnostics panel). Adding or replacing a vendor (e.g. Amplitude or Firebase) means adding a provider type, with no change to `AnalyticsTracking`, events or call sites.

## 2. Identity, sessions and user properties

### Installation ID
- UUID v4 generated on first launch, stored in `UserDefaults`. Used as the analytics user id.
- **Survives** relaunches and app updates. **Resets** on uninstall/reinstall — deliberately not stored in the Keychain, so a reinstall is a new anonymous installation and no cross-install tracking happens.
- Not IDFA/IDFV; no App Tracking Transparency prompt is needed.
- DEBUG "Reset installation ID" simulates a reinstall (D-34): it generates a new id and a new `first_seen_date`, clears stored experiment assignments (S6; they are re-derived from the new id, so the variant may change), and immediately starts a new session that reports `is_first_session = true` and `launch_kind = cold`.

### Session
- A new session starts on cold launch, or when the app returns to the foreground after **≥ 30 minutes** in the background (exactly 30:00 counts).
- The cold session starts at the first `.active` scene phase or the first tracked event, whichever comes first (D-36), so every event has a session and `session_started` is always sequence 1.
- Background time runs from the `.background` scene phase to the next `.active`, measured with the wall clock (D-35). `.inactive` alone (Control Center, the app switcher) is not leaving the app.
- `is_first_session` is true only for the installation's first session; this is remembered in `UserDefaults` across launches.
- Durations in `_s` properties are whole seconds, rounded down; a clock moved backwards gives 0.
- `session_id` (UUID) and a per-session `sequence` number are attached to every event.

### Event envelope (attached automatically)
| Field | Type | Notes |
|---|---|---|
| `event` | String | Event name |
| `timestamp` | String | ISO 8601, UTC, with milliseconds (`2026-11-13T10:15:30.250Z`) |
| `installation_id` | String | User id for analytics |
| `session_id` | String | UUID |
| `sequence` | Int | 1-based order within the session |

### User properties
User properties describe the installation, not a single event. They are set when their value changes; each change is logged (`analytics` category, old → new). Change detection is in memory, so every launch sends each launch property once (old value `nil`). In a real integration they map to the vendor's identify/user-property call, so every later event can be segmented by them. S1 implements the launch properties; `saved_products_count` arrives in S5 and `experiment_assignments` in S6.

| Property | Type | Values / format | Updated when |
|---|---|---|---|
| `app_version` | String | `CFBundleShortVersionString`, e.g. `1.0` | launch |
| `build_number` | String | `1` | launch |
| `os_version` | String | `26.0` | launch |
| `device_model` | String | hardware identifier, e.g. `iPhone17,1` (in the Simulator, the simulated model) | launch |
| `first_seen_date` | String | `yyyy-MM-dd` in UTC (installation date) | launch (value fixed at first launch; changes only on the DEBUG reset) |
| `saved_products_count` | Int | ≥ 0 | save/unsave, launch |
| `experiment_assignments` | Map<String, String> | `{ "product_card_density_v1": "control" \| "treatment" }` | assignment or override |
| `is_debug_build` | Bool | | launch |

No name, email, location, IP, advertising identifier, or free text is collected.

### Shared property values
| Property | Allowed values |
|---|---|
| `sort` / `from_sort` / `to_sort` | `default_order`, `price_asc`, `price_desc`, `rating_desc` |
| `list_context` | `browse`, `search` |
| `source` (where a product was opened from) | `catalog`, `search`, `saved` |
| `surface` (where a save/unsave happened) | `catalog_card`, `search_card`, `details`, `saved_list` |
| `error_type` | `offline`, `timeout`, `not_found`, `rate_limited`, `server`, `decoding`, `unknown` |
| `trigger` (why a first page loaded) | Browse: `initial`, `retry` (full-screen Retry), `reload` (the empty state's Reload, D-38), `sort_change`. Search: `typing`, `retry`, `sort_change` (D-48) |
| `availability` | `in_stock`, `low_stock`, `out_of_stock` |

## 3. Events

Each event: **Meaning · Trigger · Properties · Screen · Dedup · Privacy**. "Screen" is where the trigger happens.

### Lifecycle

#### `session_started`
- **Status:** Active
- **Meaning:** a new analytics session began.
- **Trigger:** cold launch, or foreground after ≥ 30 min in background (fires before `app_foregrounded`).
- **Properties:** `is_first_session` Bool; `launch_kind` `cold` | `resume`.
- **Screen:** app. **Dedup:** once per session by definition. **Privacy:** none.

#### `app_foregrounded`
- **Status:** Active
- **Meaning:** the app became active after being in the background.
- **Trigger:** scene phase `background → active` (not on cold launch).
- **Properties:** `background_duration_s` Int.
- **Screen:** app. **Dedup:** once per transition. **Privacy:** none.

#### `app_backgrounded`
- **Status:** Active
- **Meaning:** the user left the app.
- **Trigger:** scene phase `→ background`.
- **Properties:** `foreground_duration_s` Int.
- **Screen:** app. **Dedup:** once per transition. **Privacy:** none.

### Catalog

#### `catalog_viewed`
- **Status:** Active
- **Meaning:** the catalog became the screen the user is looking at.
- **Trigger:** the Catalog tab's first display after launch, and each switch to it from another tab (driven by the tab selection, D-39). **Not** re-sent when popping back from details or when the app returns from the background, even if that starts a new session.
- **Properties:** `sort`; `list_context` — of the list on screen: `search` while search results are shown, with the search's sort (D-46).
- **Screen:** Catalog. **Dedup:** once per tab visibility. **Privacy:** none.

#### `catalog_load_completed`
- **Status:** Active
- **Meaning:** the first page of the browse list was received and shown.
- **Trigger:** page-1 browse request succeeds and is applied (not stale).
- **Properties:** `trigger` (`initial` | `retry` | `reload` | `sort_change`); `sort`; `result_count` Int; `total_count` Int; `duration_ms` Int (request start to response, monotonic clock, D-40).
- **Note:** a pull-to-refresh sends `catalog_refreshed` instead (D-41). `sort_change`: the user picked another sort; page 1 of the new order replaces the list (D-45). Search results send `search_performed` instead.
- **Screen:** Catalog. **Dedup:** once per applied response. **Privacy:** none.

#### `catalog_load_failed`
- **Status:** Active
- **Meaning:** the first page of the browse list could not be loaded.
- **Trigger:** page-1 browse request fails (cancellations excluded). A failed pull-to-refresh sends `catalog_refreshed` with `result: failure` instead (D-41).
- **Properties:** `trigger`; `sort`; `error_type`; `http_status` Int (only for HTTP failures: 404, 429, other non-2xx); `has_visible_content` Bool — products were on screen when the request started (true for a sort change from a non-empty list; the screen shows the skeleton during the reload, then the full-screen error, D-45).
- **Screen:** Catalog. **Dedup:** once per failed request. **Privacy:** none.

#### `catalog_refreshed`
- **Status:** Active
- **Meaning:** a user-initiated pull-to-refresh finished.
- **Trigger:** refresh completes (success or failure); a cancelled refresh sends nothing. A refresh cancels an in-flight page request; load-more and the page footer's Retry wait until it ends (D-41).
- **Properties:** `list_context` (`search` when search results are refreshed; a search refresh sends no `search_performed`, D-48); `result` `success` | `failure`; `error_type` (failure only); `duration_ms` Int.
- **Screen:** Catalog. **Dedup:** once per pull. **Privacy:** none.

#### `catalog_page_requested`
- **Status:** Active
- **Meaning:** the user scrolled far enough (or tapped the footer Retry) to need another page.
- **Trigger:** a request for page ≥ 2 starts.
- **Properties:** `list_context` (`search` for pages of search results, D-48); `page_index` Int (1-based, so the first value sent is 2); `sort`; `is_retry` Bool.
- **Screen:** Catalog. **Dedup:** once per request; never while another page request is in flight. **Privacy:** none.

#### `catalog_page_loaded`
- **Status:** Active
- **Meaning:** an additional page was appended.
- **Trigger:** a page ≥ 2 request succeeds and is applied.
- **Properties:** `list_context`; `page_index` Int; `item_count` Int (new unique items); `has_more` Bool; `duration_ms` Int.
- **Screen:** Catalog. **Dedup:** once per applied response. **Privacy:** none.

#### `catalog_page_failed`
- **Status:** Active
- **Meaning:** an additional page could not be loaded.
- **Trigger:** a page ≥ 2 request fails (cancellations excluded).
- **Properties:** `list_context`; `page_index` Int; `error_type`.
- **Screen:** Catalog. **Dedup:** once per failed request. **Privacy:** none.

#### `product_selected`
- **Status:** Planned (S4)
- **Meaning:** the user chose a product from a list (intent to evaluate). Distinct from `product_details_viewed`, which records that details were actually shown.
- **Trigger:** tap on a product card or Saved row.
- **Properties:** `product_id` Int; `source` (`catalog` | `search` | `saved`); `position` Int (0-based index in the list); `sort` (catalog/search only).
- **Screen:** Catalog, Saved. **Dedup:** once per tap. **Privacy:** product id only.

### Search

#### `search_started`
- **Status:** Active
- **Meaning:** the user began a search.
- **Trigger:** first non-whitespace character typed into an empty search field: the trimmed query turns non-empty (D-49). Sent at the keystroke, before the debounce.
- **Properties:** `sort` (of the list on screen).
- **Screen:** Catalog. **Dedup:** once until the query becomes empty again. **Privacy:** no query text.

#### `search_performed`
- **Status:** Active
- **Meaning:** results for a search query were shown (including zero results).
- **Trigger:** page-1 search response succeeds and is applied — i.e. after debounce, and only for the latest query.
- **Properties:** `trigger` (`typing` | `retry` | `sort_change`); `query_length` Int (characters of the trimmed query); `word_count` Int (whitespace-separated words); `sort`; `result_count` Int; `total_count` Int (0 = no results); `duration_ms` Int (request start to response, after the debounce).
- **Note:** a pull-to-refresh of search results sends `catalog_refreshed` (`list_context: search`) instead; pages ≥ 2 send `catalog_page_*` with `list_context: search` (D-48).
- **Screen:** Catalog. **Dedup:** once per applied response; superseded/stale responses never fire. **Privacy:** the raw query is **not** sent (could contain anything the user types); length and word count only.

#### `search_failed`
- **Status:** Active
- **Meaning:** a search could not be completed.
- **Trigger:** page-1 search request fails (cancellations excluded).
- **Properties:** `trigger`; `query_length` Int; `error_type`.
- **Note:** the full-screen Retry sends `retry_requested` (`failed_surface: search`), then `search_performed` or `search_failed` with `trigger: retry`.
- **Screen:** Catalog. **Dedup:** once per failed request. **Privacy:** no query text.

#### `search_cleared`
- **Status:** Active
- **Meaning:** the user left search and returned to browsing.
- **Trigger:** the trimmed query goes from non-empty to empty by user action (clear button, deleting text, Cancel, or the no-results state's Clear search). Browse returns at once, without a request (D-46).
- **Properties:** `query_length` Int (of the trimmed query just before clearing); `had_results` Bool (the search list on screen had at least one product; false when the user cleared before the first results arrived, D-49).
- **Screen:** Catalog. **Dedup:** once per transition. **Privacy:** no query text.

### Sorting

#### `sort_changed`
- **Status:** Active
- **Meaning:** the user picked a different sort order.
- **Trigger:** sort selection changes to a different value. Page 1 of the list on screen reloads in the new order (`catalog_load_completed` / `search_performed` with `trigger: sort_change`). A sort change while searching changes only the search's sort (D-46).
- **Properties:** `from_sort`; `to_sort`; `list_context`.
- **Screen:** Catalog. **Dedup:** not sent when the same value is re-selected. **Privacy:** none.

### Details

#### `product_details_viewed`
- **Status:** Planned (S4)
- **Meaning:** product details were shown to the user.
- **Trigger:** details content first displayed for a navigation push.
- **Properties:** `product_id` Int; `source`; `category` String; `availability`; `has_discount` Bool; `image_count` Int; `is_saved` Bool; `content_origin` `list` | `snapshot` | `network`.
- **Screen:** Product details. **Dedup:** once per push. **Privacy:** none.

#### `product_details_load_failed`
- **Status:** Planned (S5)
- **Meaning:** fresh product data could not be loaded for the details screen.
- **Trigger:** `/products/{id}` request fails (Saved → details, or Retry).
- **Properties:** `product_id` Int; `source`; `error_type`; `showing_snapshot` Bool.
- **Screen:** Product details. **Dedup:** once per failed request. **Privacy:** none.

#### `product_gallery_interacted`
- **Status:** Planned (S4)
- **Meaning:** the user looked beyond the first product image.
- **Trigger:** first swipe to another image during a details visit.
- **Properties:** `product_id` Int; `image_count` Int.
- **Screen:** Product details. **Dedup:** once per details visit. **Privacy:** none.

### Saved

#### `product_saved`
- **Status:** Planned (S5)
- **Meaning:** the user saved a product for later.
- **Trigger:** save control toggled on.
- **Properties:** `product_id` Int; `surface` (`catalog_card` | `search_card` | `details`); `category` String; `price` Double; `position` Int (cards only); `saved_count_after` Int.
- **Screen:** Catalog, Product details. **Dedup:** once per toggle. **Privacy:** none.

#### `product_unsaved`
- **Status:** Planned (S5)
- **Meaning:** the user removed a product from Saved.
- **Trigger:** save control toggled off, or swipe-to-remove in Saved.
- **Properties:** `product_id` Int; `surface`; `saved_duration_s` Int; `saved_count_after` Int.
- **Screen:** Catalog, Product details, Saved. **Dedup:** once per toggle. **Privacy:** none.

#### `saved_products_viewed`
- **Status:** Planned (S5)
- **Meaning:** the user looked at their saved products.
- **Trigger:** Saved tab becomes visible (same rule as `catalog_viewed`).
- **Properties:** `saved_count` Int.
- **Screen:** Saved. **Dedup:** once per tab visibility. **Privacy:** none.

#### `saved_product_revisited`
- **Status:** Planned (S5)
- **Meaning:** the user came back to evaluate a product they saved in an earlier session — the "Revisit" outcome of the core journey.
- **Trigger:** `product_details_viewed` for a product whose `savedAt` is before the current session's start.
- **Properties:** `product_id` Int; `source`; `days_since_saved` Int.
- **Screen:** Product details. **Dedup:** once per product per session. **Privacy:** none.

### Reliability

#### `retry_requested`
- **Status:** Active
- **Meaning:** the user asked to try again after a failure.
- **Trigger:** tap on any Retry control.
- **Properties:** `failed_surface` `catalog` | `catalog_page` | `search` | `details`; `error_type` (of the failure being retried).
- **Screen:** Catalog, Product details. **Dedup:** once per tap. **Privacy:** none.
- **Outcome:** measured by the next load event for that surface with `trigger: retry` / `is_retry: true` (success) or its failure event.

### Experiments

#### `experiment_exposed`
- **Status:** Planned (S6)
- **Meaning:** the user actually saw a surface rendered according to their experiment variant. See [Experiments.md](Experiments.md).
- **Trigger:** first product card rendered on an eligible surface in a session.
- **Properties:** `experiment_id` String; `variant` `control` | `treatment`; `assignment_source` `hashed` | `override`; `surface` `catalog_grid` | `search_grid`.
- **Screen:** Catalog. **Dedup:** once per experiment per session (duplicates are suppressed and logged at debug level). **Privacy:** none.

## 4. Candidate events from the master spec — final mapping

| Candidate | Decision |
|---|---|
| `search_results_viewed` | Merged into `search_performed` (results are applied and shown at the same moment). |
| `search_no_results` | `search_performed` with `total_count = 0` — avoids two events for one moment. |
| `search_result_selected` | `product_selected` with `source = search`. |
| `saved_product_selected` | `product_selected` with `source = saved`. |
| `product_reviews_opened` | Not emitted — reviews are shown inline; there is no "open reviews" UI. |
| `retry_completed` | Outcome derived from the next load event with `trigger = retry` / `is_retry = true`. |
| `content_load_failed` | Replaced by surface-specific failure events (`catalog_load_failed`, `catalog_page_failed`, `search_failed`, `product_details_load_failed`). |
| Cache/performance outcomes | `duration_ms` on load events. No caching in 1.0, so there are no cache outcomes to track ([Networking.md § 3](Networking.md#3-caching--deliberately-not-implemented)). |
| *(added)* `search_failed` | Search had no failure event in the candidate list. |
| `sort_options_opened` | **Removed in S3 (D-44).** The sort control is a SwiftUI `Menu`, which reports no "opened" signal (the iOS 26.0 SDK declares only content, label and `primaryAction` initializers, checked 2026-11-13). `sort_changed` records the decisions. |
