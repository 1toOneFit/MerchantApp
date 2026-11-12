# AI Assistance Log

A running, factual record of how AI tools were used and where the developer accepted, changed or rejected their output. **Entries are only added when something actually happened** — nothing is reconstructed later. The README's AI section summarizes this file.

## Tools

| Tool | Used for |
|---|---|
| ChatGPT | Drafting the initial master specification with the developer ([MasterSpecification.md](MasterSpecification.md)) |
| Claude Code (with superpowers skills: brainstorming, writing-plans, test-driven-development, verification-before-completion; Swift skills: swift-concurrency, swift-testing, swiftui-patterns, swift-architecture) | Requirement analysis, API verification, planning docs, implementation, tests |
| Codex | Independent code review of each stage, run manually by the developer |

## Log

| Date | Stage | AI output / suggestion | Developer decision | Why |
|---|---|---|---|---|
| 2026-11-13 | Planning | Claude verified the API with `curl`: server-side search + sort + pagination combine correctly; unknown `sortBy` is silently ignored; image CDN sends `no-store`; JSON has an `ETag` but no freshness headers. | Accepted as the basis for the networking and caching design. | Replaced assumptions with observed facts. |
| 2026-11-13 | Planning | Claude flagged a spec conflict: rating on catalog cards (§2.1) vs. the experiment's control card without rating (§4). | Accepted: rating only in the treatment arm. | Keeps the experiment's variable clean. |
| 2026-11-13 | Planning | Claude recommended a reduced scope (core features + thin analytics + experiment) because the brief suggests ~3–4 hours. | **Rejected** — full master-spec scope. | Developer wants to show product-oriented engineering (instrumentation, experimentation). |
| 2026-11-13 | Planning | Claude recommended replacing the string-keyed `ServiceContainer` with plain init injection from a composition root. | **Rejected** — kept `ServiceContainer` + Configurators. | Established pattern from the developer's previous app; mitigated with a registration test. |
| 2026-11-13 | Planning | Claude recommended dropping the per-feature Domain layer as ceremony for a single data source. | **Rejected** — kept Clean Architecture `Domain`/`Data`/`Presentation`. | Architecture the developer knows and can extend live. |
| 2026-11-13 | Planning | Claude recommended `URLSession` with a plain endpoint enum. | **Changed** — Moya-style `TargetType` over `URLSession`. | Familiar endpoint abstraction, still no third-party dependency. |
| 2026-11-13 | Planning | Claude recommended updating to Xcode 27.2 (the current release) before starting. | **Rejected for now** — Xcode 26.0, documented trade-off. | Requires a macOS update that doesn't fit the assignment window. |
| 2026-11-13 | Planning | Claude recommended opening a GitHub PR per stage for a visible review trail. | **Rejected** — local branches only. | Developer controls when anything is pushed. |
| 2026-11-13 | Planning | Claude recommended reporting actual time spent in the README. | **Rejected.** | Developer's choice. |
| 2026-11-13 | Planning | Claude recommended `@Observable` + async/await + Swift 6 strict concurrency (instead of the previous app's `ObservableObject` + Combine + Swift 5 mode), Swift Testing, per-tab navigation stacks, snapshot-based Saved items, and a memory-only image cache. | Accepted. | |
| 2026-11-13 | Planning | Claude's plan used native `URLCache` revalidation for API responses plus a memory-only decoded-image cache (the image CDN sends `no-store`). | **Changed** — no caching of any kind (`urlCache = nil`, no custom cache managers). | The headers give no useful HTTP caching, and a custom cache is too much for this assignment. |
| 2026-11-13 | Planning | Claude's plan used a custom `ImageLoader` actor (de-duplication, consumer counting, memory cache) instead of `AsyncImage`. | **Changed** — `AsyncImage`, shown only while the cell is visible so loading starts on appear and stops on disappear. The image-loading stage was folded into catalog browsing. | Simpler; keeps the cancellation requirement without custom machinery. |
| 2026-11-13 | Planning | — (developer-initiated) | Added rules: protocol-first network/analytics layers with swappable providers, `develop`-based branch flow, Swift concurrency guidelines in CLAUDE.md, and no Simulator runs by the agent (build + tests only). | Reusability, review flow, and token cost. |
| 2026-11-13 | S0 | S0 registers no services yet, so Claude offered two designs for the registration test: a hand-maintained `AppContext.requiredServices` list, or Configurators exposing `resolveDependencies(from:)` that both `make(...)` and the test use. It recommended the second. | Accepted — Configurator check. | No separate list that can drift from the code that resolves services. |
