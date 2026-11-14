# MerchantCatalog

A SwiftUI product catalog for merchants who run their business from a phone, in short sessions and often on unreliable networks. It's built on the public [DummyJSON Products API](https://dummyjson.com/docs/products) and supports the journey **Discover → Evaluate → Save → Revisit**.

Prices, stock, shipping and return terms are demo data from a mock API.

## What 1.0 does

- **Browse** a 2-column grid (1 column at accessibility text sizes) with server pagination, pull-to-refresh, and distinct loading, load-more, empty and error states with Retry. Images load only while their cell is visible.
- **Search and sort** server-side. Search is debounced (300 ms), stale responses never replace newer results, and sorting always covers the whole catalog or result set, never just the loaded page. Clearing a search restores the browse list exactly as it was.
- **Evaluate** a product on a details screen whose header shows at once while the full product loads (list pages download only what the list shows): gallery, a factual "At a Glance" summary, pricing, overview, product information, shipping and availability, recent reviews. Sections without data are omitted; nothing is invented.
- **Save** from cards or details. Saved products are snapshots that survive relaunch, stay in sync on every screen and work offline; details opened from Saved show the snapshot, then refresh it.
- **Measure:** a typed analytics taxonomy, an anonymous installation id, sessions, user properties and one local A/B experiment (`product_card_density_v1`: the rating on catalog cards). A DEBUG Diagnostics sheet shows events, user properties and logs, and can force a variant or slow the network.
- **Accessibility:** Dynamic Type on all text, one VoiceOver element per card with a save action, 44 pt tap targets, dark mode through system colors.

## Requirements and running

- **Xcode 26.0**, iOS 26 Simulator. No accounts, keys or packages.
- Open `MerchantCatalog.xcodeproj`, select the `MerchantCatalog` scheme and an iPhone simulator, then Run. Tests: ⌘U, or from Terminal:
  `xcodebuild -project MerchantCatalog.xcodeproj -scheme MerchantCatalog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' test`
- Diagnostics (DEBUG builds): the stethoscope button on the Catalog tab.

## Key decisions

| Decision | Instead of | Why |
|---|---|---|
| Clean Architecture + MVVM, `@Observable`, Swift 6 strict concurrency | TCA; `ObservableObject` + Combine | An architecture I can explain and extend live, with modern concurrency guarantees |
| Protocol-first infrastructure (`APIClientType`, `AnalyticsTracking` + providers, repositories, `ExperimentService`) | Concrete singletons | Swap the HTTP stack or add an analytics vendor without touching callers |
| `ServiceContainer` + per-scene Configurators | Pure init injection | Consistent with my established architecture; a test guards against missing registrations |
| Moya-style `TargetType` over native `URLSession` | Alamofire | No dependency |
| Server-side search, sort and pagination (verified to combine) | Client-side sorting | Never misrepresent the order of the whole catalog |
| Saved items as local snapshots | IDs only + refetch | Instant, offline Saved tab; details always refetch fresh data |
| A small cancellable image loader (`.task(id:)` + `URLSession`, no cache) | `AsyncImage` | `AsyncImage` can't cancel or report its request; ours starts on appear, is cancelled on disappear (fast scrolling) and is unit-tested |

Full rationale: [docs/Architecture.md](docs/Architecture.md); every decision with who made it: [Decisions](docs/ImplementationPlan.md#decisions).

## Caching: deliberately none

No `URLCache`, no custom cache managers. Product JSON has an `ETag` but no freshness headers and images are sent `no-store`, so HTTP caching would save no round trips, and a custom cache is too much for this scope. The catalog needs a connection, and scrolled-back thumbnails download again. Saved snapshots are the user's own data, not a cache. Details: [docs/Networking.md § 3](docs/Networking.md#3-caching--deliberately-not-implemented).

## Deliberately left out

Accounts, cart/checkout, product editing, inventory/orders, remote sync, personalization/AI recommendations, remote experiment configuration, a real analytics backend, advanced filters, caching and an offline catalog, localization beyond English, iPad-specific layouts, UI snapshot tests. See [ProductSpecification § 8](docs/ProductSpecification.md#8-deliberate-exclusions).

## How we'd know it works for merchants

Funnel signals for each step of the journey: search-to-selection, details views, saves per details view, **revisits of saved products in a later session**, and load-failure rates as guardrails. The card-rating experiment has a pre-registered primary metric, secondary outcomes and guardrails. No results are claimed from a local demo. See [docs/Analytics.md](docs/Analytics.md) and [docs/Experiments.md](docs/Experiments.md).

## Release status (1.0)

Against the release completion criteria of the original brief ([MasterSpecification § 1](docs/MasterSpecification.md#1-product-intent-and-success-definition)):

| Criterion | Status |
|---|---|
| Builds and runs in a Simulator without extra setup | **Builds:** Debug and Release, 0 warnings, verified at every stage. **Runs:** the AI agent never ran the app; each review gate lists manual Simulator checks for me, and the 1.0 smoke checklist is in the S7 review log. |
| Core journey, search, sorting, pagination, saved products, loading/error states | Met. Each acceptance criterion is covered by view-model or model tests where testable; rendering is checked manually. |
| Coherent analytics and one reviewable experiment | Met. Every documented event is implemented, and a test keeps code and taxonomy equal. The experiment's assignment, exposure and metrics are documented. |
| TDD for testable behaviors | Met. Each stage wrote failing tests first and recorded it in the review log; no live network in unit tests. |
| Understandable documentation and a verified review trail | Met. An independent Codex review and my approval gate every stage ([review log](docs/ImplementationPlan.md#review-log)). |
| No fabricated research, metrics, experiment outcomes or performance numbers | Met. Unverified platform behavior is labeled as expected. |
| Current stable Xcode | **Not met.** Built with Xcode 26.0; the current release is 27.2, which needs a macOS update that didn't fit the assignment window. Opening in newer Xcode is expected to work but unverified. |

**Known limitations:** image cancellation is unit-tested down to the request, while SwiftUI cancelling the task on disappear is Apple-documented and checked manually ([Networking.md § 4](docs/Networking.md#verification)); `URLError` codes outside the documented table count as "unknown", not "offline"; categories show as the API slug in words ("Mens Shirts"); sort labels are short ("Top rated"); details opened from Saved show the snapshot's price as "Price" under a "Saved information" note until the refresh arrives; an experiment override applies at the next launch.

## AI assistance

I drafted the spec with ChatGPT. Analysis, API verification, planning and implementation were done with Claude Code, and each stage got an independent Codex review that I ran manually. [docs/AILog.md](docs/AILog.md) records, as it happened, where I accepted, changed or rejected AI output. Examples:

- I kept my own DI container and Domain layer instead of Claude's simplification suggestions.
- I replaced its planned caching and custom image loader with no caching and visibility-gated `AsyncImage`; at the final review I asked for explicit cancellation instead, so images now load through a small cancellable loader.
- I rejected moving the catalog's view model into the tab view.
- Codex reviews found real defects in Claude's code (a cancelled refresh that could still apply its response, cards that were two VoiceOver elements, a page Retry during refresh); each was fixed test-first.

## Documentation index

| Document | Contents |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Entry point and rules for AI coding sessions |
| [docs/ImplementationPlan.md](docs/ImplementationPlan.md) | Stages, status, git flow, decisions, review log |
| [docs/plans/](docs/plans/) | Task-level plan of each stage, with deviations |
| [docs/ProductSpecification.md](docs/ProductSpecification.md) | Behavior, states, acceptance criteria, accessibility |
| [docs/Architecture.md](docs/Architecture.md) | Layers, protocols, DI, navigation, concurrency, testing, trade-offs |
| [docs/Networking.md](docs/Networking.md) | Verified API facts, no-caching decision, image loading |
| [docs/Analytics.md](docs/Analytics.md) | Event taxonomy, user properties, identity |
| [docs/Experiments.md](docs/Experiments.md) | `product_card_density_v1` design and evaluation plan |
| [docs/AILog.md](docs/AILog.md) | AI usage record |
| [docs/MasterSpecification.md](docs/MasterSpecification.md) | Original input spec (not maintained) |
