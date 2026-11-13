# MerchantCatalog

A SwiftUI product catalog for merchants who run their business from a phone. It's built on the public [DummyJSON Products API](https://dummyjson.com/docs/products) and supports the journey **Discover → Evaluate → Save → Revisit**.

> **Status: in development.** The project foundation (S0), the analytics core (S1), catalog browsing (S2), search and sort (S3) and product details (S4) are in place: a paginated 2-column catalog grid with loading, empty, error and refresh states, debounced server-side search with a no-results state and an instant return to the browse list, a server-side sort menu for browse and search, a product details screen (gallery, At a Glance facts, pricing, overview, product information, shipping and availability, recent reviews) that opens instantly from a card, images that load only while visible, a cache-free network layer, catalog, search, details and lifecycle analytics, and a DEBUG Diagnostics sheet with a slow-network toggle. The Saved tab is still a placeholder; saving arrives in a later stage. Progress and stage status live in [docs/ImplementationPlan.md](docs/ImplementationPlan.md). This README is finalized in stage S7.

Prices, stock, shipping and return terms are demo data from a mock API.

## What 1.0 does (planned)

- **Browse** a 2-column grid with server pagination, pull-to-refresh, and distinct loading / load-more / empty / error states with retry. Images load only for visible cells.
- **Search and sort** server-side. Search is debounced, stale responses never replace newer results, and sorting covers the whole catalog, never just the loaded page.
- **Evaluate** products on a details screen with a gallery, a factual "At a Glance" summary, sectioned attributes and recent reviews.
- **Save** products for later. Saved items persist across launches, stay in sync on every screen, and remain viewable offline.
- **Measure:** a typed analytics taxonomy, an anonymous installation id, and one A/B experiment (rating on catalog cards). All are inspectable in a DEBUG Diagnostics panel.

## Requirements and running

- **Xcode 26.0**, iOS 26 Simulator. No accounts, keys or packages.
- Open `MerchantCatalog.xcodeproj`, select the `MerchantCatalog` scheme and an iPhone simulator, then Run. Tests: ⌘U, or from Terminal:
  `xcodebuild -project MerchantCatalog.xcodeproj -scheme MerchantCatalog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' test`

**Trade-off:** the current Xcode release is 27.2. This project is built with 26.0 because updating needs a macOS update that didn't fit the assignment window. It should open in newer Xcode, but that hasn't been verified yet.

## Key decisions

| Decision | Instead of | Why |
|---|---|---|
| Clean Architecture + MVVM, `@Observable`, Swift 6 strict concurrency | TCA; `ObservableObject` + Combine | An architecture I can explain and extend live, with modern concurrency guarantees |
| Protocol-first infrastructure (`APIClientType`, `AnalyticsTracking` + providers) | Concrete singletons | Swap the HTTP stack or add an analytics vendor without touching callers |
| `ServiceContainer` + per-scene Configurators | Pure init injection | Consistent with my established architecture; a test guards against missing registrations |
| Moya-style `TargetType` over native `URLSession` | Alamofire | No dependency |
| Server-side search/sort/pagination (verified to combine) | Client-side sorting | Never misrepresent the order of the whole catalog |
| Saved items as local snapshots | IDs only + refetch | Instant, offline-capable Saved tab; details always refetch fresh data |
| `AsyncImage`, shown only while the cell is visible | Custom image loader | Load starts on appear and stops on disappear, without custom machinery |

Full rationale: [docs/Architecture.md](docs/Architecture.md).

## Caching: deliberately none

The app does **no caching**: no `URLCache`, no custom cache managers.

- **`URLSession` caching doesn't help with this API's headers.** Product JSON has an `ETag` but no `Cache-Control`/`Expires`/`Last-Modified`, so at best it could be revalidated on every request: no fewer round trips and no offline use. Images are sent with `no-store`.
- **A custom cache layer is too much for this scope.**

The consequence: the catalog needs a connection, and scrolled-back thumbnails download again. Saved-product snapshots are the user's own data, not a cache. Details: [docs/Networking.md § 3](docs/Networking.md#3-caching--deliberately-not-implemented).

## Deliberately left out

Accounts, cart/checkout, product editing, inventory/orders, remote sync, personalization/AI recommendations, remote experiment configuration, a real analytics backend, advanced filters, caching and an offline catalog, UI snapshot tests. See [ProductSpecification § 8](docs/ProductSpecification.md#8-deliberate-exclusions).

## How we'd know it works for merchants

Funnel signals for each step of the journey:

- search-to-selection
- details views
- saves per details view
- **revisits of saved products in a later session**
- load-failure rates, as guardrails

The rating-on-card experiment has a pre-registered primary metric, secondary outcomes and guardrails. No results are claimed from a local demo. See [docs/Analytics.md](docs/Analytics.md) and [docs/Experiments.md](docs/Experiments.md).

## AI assistance

I drafted the spec with ChatGPT. Analysis, API verification, planning and implementation were done with Claude Code, and each stage gets an independent Codex review that I run manually.

[docs/AILog.md](docs/AILog.md) records, as it happens, where I accepted, changed or rejected AI output. Examples so far:

- I kept my own DI container and Domain layer instead of Claude's simplification suggestions.
- I replaced its planned caching and custom image loader with no caching and visibility-gated `AsyncImage`.

## Documentation index

| Document | Contents |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Entry point and rules for AI coding sessions |
| [docs/ImplementationPlan.md](docs/ImplementationPlan.md) | Stages, status, git flow, decisions, review log |
| [docs/ProductSpecification.md](docs/ProductSpecification.md) | Behavior, states, acceptance criteria |
| [docs/Architecture.md](docs/Architecture.md) | Layers, protocols, DI, navigation, concurrency, testing, trade-offs |
| [docs/Networking.md](docs/Networking.md) | Verified API facts, no-caching decision, image loading |
| [docs/Analytics.md](docs/Analytics.md) | Event taxonomy, user properties, identity |
| [docs/Experiments.md](docs/Experiments.md) | `product_card_density_v1` design and evaluation plan |
| [docs/AILog.md](docs/AILog.md) | AI usage record |
| [docs/MasterSpecification.md](docs/MasterSpecification.md) | Original input spec (not maintained) |
