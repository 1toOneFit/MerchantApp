# MerchantCatalog — agent entry point

SwiftUI iOS app: a product catalog for merchants (browse → evaluate → save → revisit) on the DummyJSON Products API. Built stage by stage with TDD and human review gates.

## Non-negotiable rules

- **Neutral naming.** Never write the hiring company's name, competitor names, or related brand identifiers anywhere: code, targets, bundle ids, assets, branches, commits, comments, logs, analytics, tests, docs. Use `MerchantCatalog`. Never mention a recruitment process in the UI.
- **Stage gates.** Work only on the stage marked authorized in [docs/ImplementationPlan.md](docs/ImplementationPlan.md). Finish with the review gate there, set `READY_FOR_REVIEW`, say *"This stage is ready. Please run an independent Codex review manually and share the findings."* and **stop**.
- **Never:** invoke Codex, merge, push, rebase destructively, start the next stage, self-certify a review, or enable auto-approval / permission-bypass flags.
- **Do not run the app in the Simulator** (no launching, screenshots, UI driving or simulator tools) — it wastes tokens. Verify with `xcodebuild build` and `xcodebuild test` only; list manual Simulator checks for the developer at the review gate.
- **TDD** (Red → Green → Refactor) for every testable behavior; see a test fail for the right reason before implementing. No UI snapshot tests. No live network in unit tests.
- **Truthfulness.** No fabricated research, metrics, experiment results, or performance numbers. Label platform behavior as verified (with date and method) or expected.
- **Analytics code and [docs/Analytics.md](docs/Analytics.md) change in the same commit.** Event status `Planned` → `Active` when implemented.
- **No caching** of any kind (no `URLCache` use, no custom cache managers). Saved-product snapshots are user data, not a cache. Rationale: [docs/Networking.md § 3](docs/Networking.md#3-caching--deliberately-not-implemented).
- No third-party dependencies without the developer's approval. README does not report time spent.

## Branching

`main` (release) ← `develop` (integration) ← `feature/<stage>`. Every feature branch starts from up-to-date `develop` and is merged back into `develop` **by the developer**. `develop` → `main` happens only at release, by the developer.

## Swift concurrency

Follow modern Swift Concurrency best practices. Prefer structured concurrency and explicit actor isolation. Use `@MainActor` only where appropriate (UI state, view models, routers), propagate cancellation, avoid unnecessary unstructured `Task`s and unsafe `Sendable` workarounds (`@unchecked Sendable`, `nonisolated(unsafe)`) unless justified in a comment. Before implementation, inspect the project's Swift version, deployment target, and concurrency settings. Validate all concurrency changes with an Xcode build and tests.

## Skills to use

Process: `superpowers:writing-plans` (stage task plan), `superpowers:test-driven-development`, `superpowers:verification-before-completion`. Swift: `swift-concurrency`, `swift-testing`, `swiftui-patterns`, `swift-architecture`, `ios-networking` — during implementation **and** self-review.

## Startup protocol (every new conversation)

1. Read this file.
2. Read **Current state** and **Stage status** in [docs/ImplementationPlan.md](docs/ImplementationPlan.md).
3. Run `git status` and `git branch`; reconcile docs with the repository. Report any mismatch before doing anything.
4. Identify the next **authorized** stage and any unresolved review gate.
5. If a stage is `READY_FOR_REVIEW` or `CHANGES_REQUESTED` without findings from the developer, **stop and ask**.
6. Read only what the stage needs: its plan section plus the docs it links.
7. Confirm scope with the developer, then `git switch develop && git switch -c <branch>`.

A review/fix cycle may continue in the same conversation; a new stage starts in a new conversation.

## Architecture at a glance

- Clean Architecture + MVVM. Folders: `App/`, `Core/`, `Networking/`, `Shared/<Area>/{Domain,Data}`, `Features/<Feature>/{Domain,Presentation}`, `DesignSystem/`.
- **Protocol-first infrastructure.** Consumers depend only on protocols: `APIClientType` (network), `ImageLoading` (images), `AnalyticsTracking` (analytics), repository protocols. Concrete types (`URLSessionAPIClient`, `AnalyticsService` + `AnalyticsProvider`s) are swappable without changing the protocol or call sites. Register services in the container under their protocol type.
- View models (`@MainActor @Observable`) call protocols, emit analytics, and ask the router to navigate. Views render state and call view-model intents.
- DI: `ServiceContainer` configured in `AppContext`; per-scene **Configurators** resolve and inject via initializers. View models never touch the container.
- Navigation: `NavigationStack`/`navigationDestination` **only** in `App/AppTabView.swift`; no `NavigationLink` (enforced by `NavigationRuleTests`).
- Images: `ProductImageView` loads through `ImageLoading` (`URLSessionImageLoader`, own session, no cache) in `.task(id: url)`: it starts on appear and SwiftUI cancels it on disappear, which cancels the request (D-78).

Details: [docs/Architecture.md](docs/Architecture.md).

## Commands (Xcode 26.0, iOS 26 Simulator, headless)

```bash
xcodebuild -project MerchantCatalog.xcodeproj -scheme MerchantCatalog \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' build
xcodebuild -project MerchantCatalog.xcodeproj -scheme MerchantCatalog \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' test
```

`iPhone 17` because this machine has several simulators named `iPhone 17 Pro`. Both commands verified on 2026-11-13 in S0.

## Docs map

| Need | File |
|---|---|
| Progress, stages, decisions, review log | [docs/ImplementationPlan.md](docs/ImplementationPlan.md) |
| What the app does, acceptance criteria | [docs/ProductSpecification.md](docs/ProductSpecification.md) |
| How it's built, trade-offs | [docs/Architecture.md](docs/Architecture.md) |
| API facts, no-caching decision, images | [docs/Networking.md](docs/Networking.md) |
| Event taxonomy, user properties | [docs/Analytics.md](docs/Analytics.md) |
| A/B experiment | [docs/Experiments.md](docs/Experiments.md) |
| AI usage record | [docs/AILog.md](docs/AILog.md) |
| Original input spec (not maintained) | [docs/MasterSpecification.md](docs/MasterSpecification.md) |

## Working style

State assumptions; ask when a decision belongs to the developer. Keep changes focused; no speculative abstractions or drive-by refactors. Record decisions in the plan's Decisions table, and add an AILog entry when the developer changes or rejects AI output. Verify with build and tests before claiming anything works.
