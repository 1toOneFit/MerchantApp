> **Original input specification — not maintained.** Drafted by the developer with ChatGPT before implementation started and kept here unchanged as the starting brief for spec-driven development. Where it conflicts with later decisions, the maintained documents win: [ProductSpecification.md](ProductSpecification.md), [Architecture.md](Architecture.md), [ImplementationPlan.md](ImplementationPlan.md).

---

# Merchant Catalog — Master Product & Development Specification

**Release:** 1.0 / Home assignment  
**Platform:** iOS (SwiftUI, current stable Xcode)  
**Data source:** [DummyJSON Products API](https://dummyjson.com/docs/products)  
**Working method:** Spec-driven development, test-driven development (TDD), feature branches, human-controlled code reviews

> **Important first-run instruction:** Treat this document as the initial specification, **not** as authorization to implement the entire app. Your first task is to analyze it, propose the documentation architecture, produce a detailed stage-by-stage implementation plan, and **stop for my explicit approval**. Do not begin application feature development until that approval is given.

## 1. Product intent and success definition

Build a small, credible mobile product catalog for merchants who manage their business from a phone. The experience should feel like something suitable to evolve into a real product, not a two-screen API demo.

**Core user journey: Discover → Evaluate → Save → Revisit.** A merchant should be able to find relevant products quickly, understand important attributes, and save interesting options to return to later.

Optimize for clear user value, intentional scope, responsiveness, reliability, and measurable product behavior. Avoid speculative features and unnecessary abstractions. Use the mock API's available fields as demo content; do not imply that its inventory, shipping terms, or prices represent another commercial platform.

**Release completion criteria:** The app builds and runs in a Simulator without extra setup; supports the core journey, search, sorting, pagination, saved products, and thoughtful loading/error states; has coherent analytics and one reviewable experiment; follows TDD for testable behaviors; and has understandable documentation and a verified review trail. No fabricated research, usage metrics, experiment outcomes, or measured performance numbers.

### Naming and neutrality

Use only neutral project and product naming (for example, `MerchantCatalog` or `CatalogApp`). **Never place the hiring company's name, competing company names, or related brand identifiers in app code, targets, bundles, assets, branches, comments, logs, analytics, tests, or generated project documentation.** The application must stand alone as an abstract merchant catalog. Do not mention the recruitment process inside shipped UI.

## 2. Product requirements — release 1.0

### 2.1 Catalog

- Display a polished, scrollable list/grid of products with image, title, price, and appropriate product context; show rating and category when relevant and available.
- Allow opening product details and saving/unsaving products directly from catalog cards.
- Support incremental server-backed pagination, loading-more feedback, and pull-to-refresh.
- Preserve useful browsing state when returning from a detail screen.
- Clearly distinguish initial loading, pagination loading, refreshing, no content, and failures; give actionable retry behavior.

**Why:** Merchants browse in short sessions and need to recognize promising items with minimal friction.

### 2.2 Search and sorting

- Prominent keyword search using server-supported search behavior; avoid unnecessary requests while typing and prevent stale responses replacing current results.
- Clear search, no-results handling, and consistent transitions between browsing and search.
- Sort by ascending price, descending price, and descending rating where supported. Make the current sort visible.
- Never misrepresent a sort of one loaded page as a sort of the entire catalog; validate combined search/sorting/pagination API behavior before selecting the final UX.

**Why:** Search and ordering help merchants find relevant options faster, but must be semantically correct.

### 2.3 Product details and insights

- Display photo gallery, title, description, brand/category where available, price/discount, rating/reviews, SKU, relevant specifications, shipping/availability, return policy, and minimum order quantity where supplied.
- Organize information into scannable sections such as Overview, Pricing, Product Information, Shipping & Availability, and Reviews.
- Show a compact **At a Glance / Product Insights** summary of *factual* decision-making information.
- Provide save/unsave action with consistent state across screens.
- Do not invent a proprietary product score, margin estimate, recommendation, or business claim unsupported by data.

**Why:** The product detail screen should help evaluation, not just reproduce raw JSON.

### 2.4 Save for later

- Save/unsave products from catalog and details.
- Provide an accessible Saved view or filter, empty state, and path back to product details.
- Persist saved selections across application relaunches, and reflect changes consistently in all views.
- Treat saved identifiers as durable selections; do not assume that previously fetched remote price/availability data remains forever correct.

**Why:** Product evaluation often spans multiple short mobile sessions.

### 2.5 User-facing resilience

- Responsive loading and scrolling; non-blocking refresh when usable content exists.
- Understandable errors, retry, and offline/stale-content messaging *only if actual supported cached content is available*.
- Suitable placeholders, image failure states, and recoverable empty states.
- Standard, accessible iOS interaction patterns; basic Dynamic Type, VoiceOver labeling, and appropriately sized tap targets where practical.

**Why:** Network unreliability and perceived speed are real product concerns.

## 3. Analytics: event taxonomy, user properties, and diagnostics

Build an intentional, typed analytics vocabulary covering **all meaningful user actions, navigation steps, and key product outcomes**, without generating unnecessary noisy events per keystroke or rendering cycle. Technical request-by-request diagnostics belong primarily in logging. Maintain one authoritative analytics taxonomy in documentation; exact document organization is the implementing agent's decision.

For **each event**, define its name, meaning, precise trigger, properties and types, allowed values, source/screen, privacy considerations, and frequency/deduplication rules. Ensure the code and taxonomy match. Examples below are a starting inventory, **not an exhaustive final list**; identify any missing meaningful interactions during planning:

| Area | Candidate events |
|---|---|
| Lifecycle | `session_started`, `app_foregrounded`, `app_backgrounded` |
| Catalog | `catalog_viewed`, `catalog_load_completed`, `catalog_load_failed`, `catalog_refreshed`, `catalog_page_requested`, `catalog_page_loaded`, `catalog_page_failed`, `product_selected` |
| Search | `search_started`, `search_performed`, `search_results_viewed`, `search_no_results`, `search_cleared`, `search_result_selected` |
| Sorting | `sort_options_opened`, `sort_changed` |
| Details | `product_details_viewed`, `product_details_load_failed`, `product_gallery_interacted`, `product_reviews_opened` (only if such UI exists) |
| Saved | `product_saved`, `product_unsaved`, `saved_products_viewed`, `saved_product_selected`, `saved_product_revisited` |
| Reliability | `retry_requested`, `retry_completed`, `content_load_failed`, meaningful performance/cache outcomes where verifiable |
| Experiments | `experiment_exposed` |

Avoid overlapping or contradictory definitions (e.g., choose a clear distinction between `product_selected` and `product_details_viewed`). Do not emit events for UI that does not exist.

### User properties and experiment cohort information

Support an **anonymous stable installation/user identifier**, and an independently defined concept of **user properties**. User properties may include relevant platform/app attributes, declared preferences if implemented, and **stable experiment assignments** (e.g., `experiment_assignments: { product_card_density_v1: treatment }`). These properties must be accessible for segmentation and correlated with event context in a real analytics integration. Document how installation ID resets and property changes behave; do not collect unnecessary personal data.

### Experiment assignment vs. exposure

Keep **both** concepts:

- **Assignment:** a user/installation is allocated a stable variant; it can be represented in experiment properties and persisted.
- **Exposure:** the user actually reaches a UI surface where that variant is rendered. Track this with one **generic** `experiment_exposed` event containing `experiment_id` and `variant`, not a unique event type for every experiment or button.

Track exposure at an appropriate granularity and avoid repeated exposure spam. Variant assignment alone does not demonstrate that a user saw the treatment. Normal outcome events can then be segmented using experiment context. Explain the difference in the experiment documentation.

### Metrics

Do **not** impose a permanent North Star or a mandatory global core metric at this stage. Instrument sufficiently meaningful, consistent events so product metrics and funnels can be defined later. For the concrete A/B experiment, however, document a proposed primary evaluation metric, secondary outcomes, and guardrails **before** claiming it could be analyzed. No real analytics backend or real-world results are required. Provide an inspectable development analytics sink/debug view or comparable practical verification mechanism.

## 4. One focused A/B experiment

**Experiment ID:** `product_card_density_v1`  
**Question:** Does exposing a product rating in the catalog card help merchants make more effective product decisions, or does it add visual noise?

- **Control:** image, title, price, save action.
- **Treatment:** the same card, plus rating when available.
- Hold the other interactions and functions constant so the impact is attributable to one variation.
- Persist a stable anonymous assignment; support a development-only way to force either variant.
- Track actual exposure and downstream behavioral outcomes; define clear exposure, eligibility, and deduplication rules.
- Document a proposed experiment analysis approach, including sample/traffic requirements and limitations. **Do not claim an A/B-test winner or statistical significance from a local demo.**

**Why:** Demonstrates testable product hypotheses rather than aesthetic preference.

## 5. Networking, URLSession and HTTP caching

Use the [DummyJSON Products API](https://dummyjson.com/docs/products) for catalog, details, search, and supported sorting/pagination. Handle request cancellation, slow/failing requests, and consistent UI state. Validate API behaviors that combinations of search/sort/pagination depend on.

### Verified API observations

A manually inspected `GET /products?limit=20` response returned an `ETag`, but **did not return `Cache-Control: max-age` or `Expires`**. A subsequent request with `If-None-Match` returned **HTTP 304 Not Modified**. This confirms that the endpoint supports **ETag-based conditional validation**, **not** that the native client will always store the response or reuse it for any guaranteed freshness window.

### Caching requirements

- **Prefer native `URLSession` and `URLCache` with HTTP-protocol cache behavior** rather than creating an application-level cache service.
- Verify, do not assume, whether a response is stored, when revalidation occurs, whether conditional headers are sent automatically, and what data the application receives on `304`.
- Do not invent a four-hour TTL or claim no request occurs for four hours. An ETag is a validator, not a freshness lifetime.
- Do not bypass server cache restrictions such as `no-store`.
- Do not promise deterministic offline access through `URLCache` alone; if that matters, explicitly surface the trade-off and seek approval before adding persistence beyond saved selections.
- Record empirical validation steps/results via tests or diagnostic network inspection (e.g., proxy observation) and distinguish verified facts from aspirations.
- Avoid overengineering: if the API's headers limit native caching, document that limitation and prefer a truthful, minimal implementation.

**Why:** Respect server-defined freshness, reduce unnecessary data transfer when legitimately possible, and demonstrate sound trade-offs.

## 6. Asynchronous images and cancellation

All remote images must load **asynchronously**, with loading placeholders, success rendering, and recoverable failure states. Prefer native iOS image-loading facilities if they meet the actual requirements; do not add a third-party dependency merely by habit.

- Start image work when a visual consumer needs the image.
- When a cell leaves the visible area or its view task is cancelled, **cancel its no-longer-needed image work** when safe and supported.
- Handle rapid scrolling, cell reuse/identity changes, out-of-order completion, duplicate requests, and unnecessary redownloads.
- Never cancel a shared request if another visible consumer still needs it.
- Keep decoding, sizing, and rendering work from blocking main-thread responsiveness.
- **Measure or verify** actual cancellation and cache behavior of the selected native loader; do not assert that `onDisappear` always terminates underlying network traffic.
- Scope tests to controllable image request lifecycle and cancellation behavior; use a diagnostic check for behavior that cannot be proven in unit tests.

**Why:** Smooth scrolling and sensible resource usage are user-facing quality attributes.

## 7. Structured logging and observability

Create coherent structured diagnostics with appropriate categories and severity. In development builds, make it practical to inspect:

- App lifecycle and navigation.
- Network request method, sanitized URL, identifier, latency, status, errors, retries, and cancellation.
- Cache-relevant headers and observable cache/revalidation outcomes.
- Image load lifecycle and failures.
- Analytics events, their properties, and user-property/experiment-assignment changes.
- Experiment exposure, persistence, and variant selection.
- Saved-item persistence, important state changes, and performance diagnostics.

Keep **analytics** (meaningful product behavior) distinct from **logs** (high-volume debugging). Do not print tokens, secrets, full sensitive payloads, personally identifying information, or raw search terms by default. Do not make extremely noisy production logging the default. Make logging inspectable during review.

## 8. TDD and verification

Use **Red → Green → Refactor** for all meaningful, testable behavior:

1. Define expected behavior and acceptance criteria.
2. Write a failing unit test and confirm the correct failure.
3. Implement only what is needed to pass.
4. Run the test, refactor, and rerun the relevant tests.
5. Verify applicable integration/diagnostic behavior and Simulator flows.

Unit tests should cover, as applicable: models/mapping, search timing and cancellation, stale response protection, pagination and edge cases, sorting, saved-item persistence and synchronization, loading/error/retry states, analytics event generation/properties, experiment assignment/exposure/deduplication, and any controllable image request/cancellation logic. Cache HTTP semantics and native image loader behavior may also need targeted integration tests or direct observation; **do not pretend unit tests prove platform/network behavior that they cannot**.

Tests should be deterministic, use controlled inputs/dependencies, and avoid reliance on live API availability in the unit test suite. **UI snapshot tests are explicitly excluded.** A working Simulator build and manual smoke verification are required at appropriate review gates.

## 9. Documentation system: guidance, not a mandatory file inventory

Implement a maintainable Markdown knowledge base with **progressive disclosure**. `CLAUDE.md` should be short, unambiguous, and act as the root entry point for future Claude Code conversations. `README.md` is the human-facing entry point and must include a navigable **Documentation Index** with relative links.

**The implementing agent has the final say on exact supporting files, grouping, and names.** The following is **illustrative only**; do not create files merely because they appear here:

```text
CLAUDE.md                 # concise agent entry point
README.md                 # human overview, setup, trade-offs, documentation index
docs/
  ProductSpecification.md # user problems, scope, behavior, acceptance criteria
  Architecture.md         # design, dependencies, state/data flow, trade-offs
  Taxonomy.md             # canonical event and user property definitions
  Experiments.md          # hypothesis, variants, assignment, exposure, evaluation
  Networking.md           # API, URLSession, caching constraints and verification
  ImplementationPlan.md   # staged feature/branch/test/review plan and progress
  ...                     # add or consolidate only when warranted
```

The agent may combine, rename, or add documents, including lightweight decision records, logging, image-loading, testing, or workflow notes, **when justified**. Avoid duplicating instructions across multiple documents. What matters is that product requirements, architectural rationale, analytics taxonomy, experiments, test approach, implementation stages, and **current progress/review state** remain discoverable and accurate.

### `CLAUDE.md` expectations

- Keep it concise (target roughly 50–80 lines or less, unless justified).
- State only durable project constraints, navigation links, non-negotiable workflow rules, and how to resume work.
- Point to the current plan/state rather than embedding full specifications.
- Apply engineering discipline: clarify assumptions, prefer focused changes, avoid speculative abstractions, review generated code, and verify before claiming completion.

### `README.md` expectations

- Explain the product and merchant problem, included functionality, setup/run/tests, important decisions and alternatives, deliberate exclusions, caching behavior and limitations, analytics/experimentation intent, and AI assistance.
- Explicitly describe the Markdown documentation library and link to its sources of truth.
- Keep it readable: use links to deeper docs rather than a giant duplicate specification.
- Report AI use truthfully, including what it accelerated and examples of developer changes/rejections **only when those actually occurred**.

## 10. Spec-driven implementation plan and Git workflow

**Planning is the first deliverable.** Before writing application feature code:

1. Interpret the requirements and identify conflicts, assumptions, and product/technical trade-offs.
2. Propose the minimum useful documentation structure and create an initial concise `CLAUDE.md` and relevant docs.
3. Prepare a **detailed, ordered implementation plan**, divided into small independently reviewable stages/features.
4. For each stage include: objective and user value, boundaries, dependencies, proposed branch name, acceptance criteria, unit tests to write first, validation steps, docs updates, and Codex review checkpoint.
5. Include dependencies and identify any foundation/infrastructure stages that are necessary, without splitting tiny tasks into excessive branches.
6. Persist a plan and current status in the repository; explain how fresh chats resume from it.
7. **Stop and ask me to approve the plan before starting feature implementation.**

### Branching rules

- Each independently reviewable stage/feature has its **own dedicated branch**. Choose meaningful `feature/...` names; do not treat the example names as mandated.
- Keep commits focused and reviewable; no unrelated changes.
- Do not automatically merge, rebase destructively, or begin the next stage.
- Normal tool and terminal permission prompts must remain enabled. **Never enable auto-approval or permission-bypass flags** to bypass user authorization.

### Review gate — required after *every* stage

After completing a stage:

1. Run all relevant unit tests and the applicable suite; build and verify Simulator behavior as relevant.
2. Update affected documentation and persistent stage status.
3. Record the branch and commit, changed-file summary, test results, known limitations, and any open questions.
4. Mark status **`READY_FOR_REVIEW`**, not `COMPLETED`.
5. Tell me explicitly: **“This stage is ready. Please run an independent Codex review manually and share the findings.”**
6. **Stop.** Do not invoke Codex yourself, presume approval, merge, or start another feature.

If I provide review findings, assess and address accepted issues **on the same feature branch**, add tests when needed, reverify, and request re-review. The agent must not self-certify that review passed. After **my explicit final approval**, update the persisted state to `APPROVED`/`COMPLETED` as appropriate and prepare the handoff. Any merge or transition happens only when I explicitly authorize it.

## 11. Fresh-chat-per-stage context management

**Start each new implementation stage in a fresh Claude Code conversation** to reduce context saturation, token waste, and accidental dependence on previous chat history. A review/fix cycle can stay in the current chat; a **new stage** belongs in a **new chat**.

The repository—not prior conversation history—is the persistent source of truth. Maintain an easily discoverable stage/status record in `ImplementationPlan.md` **or another suitable file chosen by the agent**. It must identify:

- Stage IDs and status (`PLANNED`, `IN_PROGRESS`, `READY_FOR_REVIEW`, `CHANGES_REQUESTED`, `APPROVED`, `COMPLETED`).
- Current branch and relevant commits; last completed stage and next authorized stage.
- Pending human approval/Codex review and open findings.
- Tests and verification performed, outstanding blockers, and important decisions.
- Links to the minimum relevant documentation for the next stage.

**New chat startup protocol:**

1. Read root `CLAUDE.md`.
2. Locate the authoritative plan and state/handoff entry.
3. Inspect Git status and current branch; reconcile docs against repository reality.
4. Identify the next **authorized** stage and any unresolved review gate.
5. Read only the stage-relevant documents (progressive disclosure).
6. If previous work awaits review or approval, **stop**; do not silently continue.
7. Otherwise confirm stage scope and proceed only within existing approvals.

**End-of-stage handoff:** Leave the persistent context accurate **before** ending the chat. Once approval is recorded, state the completed feature, branch/commit, verification, review status, and next stage. Explicitly recommend: **“Start a new Claude Code conversation for the next stage; it should read `CLAUDE.md` and the persisted plan/state.”** Do not rely on unrecorded verbal decisions.

## 12. AI-assisted development principles

Use AI heavily for implementation and routine coding, while retaining deliberate human ownership of problem framing, feature priority, UX trade-offs, architecture, tests, code review, and approvals. AI output is proposed code, not automatically trusted code. Do not misrepresent work or decisions as manually performed when they were AI-assisted, and do not invent rejected suggestions or empirical outcomes.

Prefer simple solutions that are easy to explain. Keep scope focused, prevent unrelated refactors, and record important decisions succinctly. The work should demonstrate a product engineering mindset through **user problem → chosen feature → observable behavior → testable hypothesis → meaningful instrumentation → evidence-based iteration**, without needing a live production analytics backend.

## 13. Deliberate exclusions

Do **not** add: login/authentication, cart/checkout, product editing/publishing, order or inventory management, remote sync, complex personalization, AI recommendations, remote experimentation infrastructure, production dashboards, speculative advanced filtering, or UI snapshot tests. Do not include a roadmap section of speculative future opportunities unless needed to explain a specific trade-off.

## 14. Immediate instructions to the implementing agent

**On the first conversation, do only the following:**

1. Read this specification and verify relevant API assumptions as needed.
2. Propose a lean, agent-maintained documentation knowledge base; the suggested file list is *not binding*.
3. Prepare `CLAUDE.md`, a human-facing `README.md` outline or initial version, and only the documentation needed to support planning.
4. Define how analytics taxonomy, experiment cohorts/exposure, caching, image cancellation, and TDD will be approached and validated.
5. Produce a detailed feature/stage plan with branch names, acceptance criteria, tests, review gates, and persistent new-chat handoff state.
6. Surface important unresolved decisions and recommended defaults.
7. Present the plan and **stop for my explicit approval**.

**Do not start implementing application features, automatically invoke Codex, auto-approve permissions, merge, or advance to the next stage.**
