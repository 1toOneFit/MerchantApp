# Experiments

**Status:** Approved by the developer (2026-11-13). Metrics below are a **pre-registered proposal**. No experiment has been run; no result, winner or significance is claimed.

## `product_card_density_v1`

### Question and hypothesis

**Question:** Does showing a product's rating on the catalog card help merchants make better product decisions, or does it add visual noise?

**Hypothesis:** Rating is a fast quality signal. With it on the card, merchants open fewer poor-fit products and save more of what they open, without browsing less. We'd expect **a higher share of exposed installations saving at least one product**, with no drop in browsing depth.

### Variants

| Variant | Catalog/search card | Allocation |
|---|---|---|
| `control` | image, title, price, save button | 50 % |
| `treatment` | same card **plus rating** (★ 4.6) | 50 % |

Everything else is identical across arms: card size and layout grid, details screen, Saved list, sort options (including "Rating: High to Low"), search, and all other interactions. The card reserves the same height in both arms, so the number of cards per screen does not change. That way rating is the only visual difference.

### Assignment (stable, local)

- **Unit:** installation (`installation_id`, see [Analytics.md § 2](Analytics.md#2-identity-sessions-and-user-properties)).
- **Bucketing:** first 8 bytes of `SHA-256("product_card_density_v1:" + installation_id)` as `UInt64`, modulo 10 000; `< 5 000` → `control`, otherwise `treatment`. Swift's `hashValue` is **not** used: it is seeded per process and would change the variant on every launch.
- **Persistence:** the first computed variant is stored in `UserDefaults` and reused afterwards. This way a later allocation change can't silently move existing users.
- **User property:** `experiment_assignments.product_card_density_v1` is set when the variant is assigned.
- **Reset:** a new installation id (reinstall, or DEBUG reset) clears stored assignments and re-buckets.

**Assignment ≠ exposure.** An assigned installation may never open the catalog (e.g. it goes straight to Saved), or may quit during the initial load. Assignment alone says nothing about what the user saw, so analysis is based on exposure.

### Development override (DEBUG only)

The Diagnostics panel offers **Auto / Control / Treatment**. Overrides are stored separately from assignments, are compiled out of Release builds, and set `assignment_source = override` on exposure. Analysis excludes override and debug-build traffic (`is_debug_build`).

### Eligibility and exposure

- **Eligible:** every installation. There is no targeting.
- **Exposure surfaces:** the catalog grid and the search results grid (both render the experiment card).
- **Exposure event:** `experiment_exposed { experiment_id, variant, assignment_source, surface }`. It fires when the **first product card renders** on an eligible surface in a session, for **both** arms, since control users are exposed to the control card.
- **Deduplication:** once per experiment per session (`ExposureTracker`, keyed by session id + experiment id). Repeats are suppressed and logged at debug level. Analysis uses each installation's **first** exposure.
- Not exposure: assignment, app launch, a failed initial load with no cards, the Saved tab, or the details screen.

### Proposed evaluation (defined before any data)

**Analysis population:** installations with ≥ 1 `experiment_exposed` (`assignment_source = hashed`, `is_debug_build = false`), analysed by assigned variant. Outcomes are counted from first exposure.

| Kind | Metric | Definition |
|---|---|---|
| **Primary** | Save conversion | Share of exposed installations with ≥ 1 `product_saved` within 7 days of first exposure |
| Secondary | Selection efficiency | `product_saved` ÷ `product_details_viewed` per installation (do they save more of what they open?) |
| Secondary | Card click-through | `product_selected` (source catalog/search) ÷ (`catalog_viewed` + `search_performed`) |
| Secondary | Save quality | Share of savers with ≥ 1 `saved_product_revisited` within 7 days |
| Secondary | Regret | `product_unsaved` within the same session as the save ÷ `product_saved` |
| Secondary | Rating sort usage | Share of exposed installations with `sort_changed` to `rating_desc` |
| Guardrail | Browsing depth | `catalog_page_loaded` per session (visual noise could reduce scrolling) |
| Guardrail | Reliability parity | `catalog_load_failed`, `catalog_page_failed` rates (should not differ; a difference points to an implementation bug) |
| Guardrail | Return rate | Share of installations with a `session_started` 1–7 days after first exposure |
| Guardrail | Sample ratio | Exposed counts per arm vs. expected 50/50 (chi-square). A mismatch invalidates the readout |

**Statistical approach:** two-sided two-proportion test on the primary metric, α = 0.05, power 0.80, fixed horizon (no early stopping on peeks; a sequential method would be needed to monitor continuously). Secondary metrics are descriptive unless corrected for multiple comparisons.

**Sample size (illustrative arithmetic, not data):** n per arm ≈ (z₀.₉₇₅ + z₀.₈₀)² × [p₁(1−p₁) + p₂(1−p₂)] / δ². With an **assumed** baseline save conversion of 20 % and a minimum detectable effect of +2 points (20 % → 22 %): 7.84 × (0.16 + 0.1716) / 0.0004 ≈ **6 500 exposed installations per arm**. The real baseline must come from pre-experiment data. Run for at least two full weeks to cover weekly usage cycles, even if the sample is reached earlier.

**Decision rule (proposal):** ship `treatment` only if the primary metric improves at the chosen significance with no guardrail degrading beyond an agreed threshold (e.g. browsing depth −5 %). Otherwise keep `control`. An inconclusive result is a valid outcome.

### Limitations

- This is a local demo with no analytics backend, so nothing is collected or analysed. The app demonstrates assignment, exposure and instrumentation only.
- Demo data: every product has a rating (2.51–4.99). Real catalogs have missing or low-count ratings, which would change the treatment's effect.
- Sort by rating exists in both arms. Control users may sort by a value they can't see; this is tracked as a secondary metric rather than removed, since removing it would change more than one thing.
- Installation ≠ person: reinstall or a second device creates a new unit.
- Local assignment can't be stopped remotely. Ending the experiment needs an app update, because remote configuration is out of scope for 1.0.
- Novelty effects are possible in the first days.
