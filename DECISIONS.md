# Fit-gap engine — design decisions

## 5. How did you structure the class internally — one big method, strategy pattern, or something else? Why?

The engine uses **small, named private operations** orchestrated by **`EVALUATE_GAPS`**, not a single monolithic method.

- **`BUILD_ACTUAL_INDEX`**: turns the actual table into a **hashed table with unique key `scope_item`** so each baseline row resolves its actual row in **O(1)** average time.
- **`EVALUATE_STANDARD_RULES`**: one pass over the baseline; for each row it applies the four standard rules in a fixed order (missing → deactivated → extra custom fields → custom code risk). Each rule either appends **one** gap or does nothing, matching the “one gap per rule instance” aggregation rule.
- **`SORT_GAPS`**: maps severity to a numeric rank, sorts **H → M → L**, then **score descending**, then **`scope_item` ascending** as an explicit tie-break (see question 6).
- **`EVALUATE_ADDITIONAL_RULES`**: **protected**, empty in the base class — the **Open/Closed** hook for new rules without editing the standard pipeline.

This is **not** a full strategy/registry framework (to stay small and Cloud-friendly), but it follows the same idea: **one place for orchestration**, **separate places for indexing, rule evaluation, and ordering**. That keeps **`EVALUATE_GAPS`** readable, makes branches easy to cover with unit tests, and avoids duplicating lookup logic.

## 6. What happens when two rules produce the same score for different scope items? How does your ordering behave? Is it stable?

The brief only requires ordering by **severity** (H → M → L) and then **score descending**. When **severity and score are equal**, the implementation still has to pick a **deterministic** order (otherwise “same inputs → same output” is ill-defined).

**Behavior:** after the primary sort keys, gaps are ordered by **`scope_item` ascending** (lexicographic on the fixed-length `scope_item` field). So two `MISSING` gaps both at **H / 90** for `'002'` and `'003'` always appear as **`002` then `003`**, regardless of the order those baseline rows were supplied.

That is **not** “stable sort preserving insertion order”: it is an **explicit tertiary key**. It is **fully deterministic** and **stable in the sense of repeatable grading runs**, but **not** stable in the narrow sense of preserving original relative order for equal keys.

## 7. How would you extend this to handle a new rule (e.g. `DEPRECATED_SCOPE_ITEM`) without modifying existing methods? Show the extension point in your code.

**Extension point:** subclass `ZCL_S4A_FITGAP_ENGINE` and **redefine** `EVALUATE_ADDITIONAL_RULES`. From there, call **`APPEND_GAP`** ( **`PROTECTED`** ) to emit gaps. The existing **`EVALUATE_GAPS`**, **`EVALUATE_STANDARD_RULES`**, **`BUILD_ACTUAL_INDEX`**, and **`SORT_GAPS`** stay unchanged.

Reference in repo:

- Base hook (no-op default): `evaluate_additional_rules` in `src/zcl_s4a_fitgap_engine.clas.abap`.
- Example consumer: local class `ltcl_fitgap_engine_with_ext` in `src/zcl_s4a_fitgap_engine_test.clas.locals_def.abap` / `src/zcl_s4a_fitgap_engine_test.clas.locals_imp.abap` (test-only illustration; locals live outside the global class source so ADT can split definition vs. implementation).

A production extension would be a **global** subclass (e.g. `ZCL_S4A_FITGAP_ENGINE_EXT`) that only contains the new rule logic in `evaluate_additional_rules`, optionally reading deprecation metadata from constructor injection or immutable configuration objects — still **no DB** inside the engine if you pass data in from outside.

## 8. If the `actual` input had 500,000 rows, where is the bottleneck and how would you fix it — still in pure ABAP, no DB?

**Likely bottlenecks (in order):**

1. **Building the actual index** — one full scan of ~500k rows plus hash inserts. This is **O(n)** and usually acceptable in batch; the main limit is **memory** for the hashed table (and the source table if it is held twice).
2. **Baseline loop** — if the baseline also has hundreds of thousands of rows, total work is **O(|baseline|)** with **O(1)** lookups per row; still linear, but dominates if `|baseline|` is large.
3. **Many emitted gaps** — sorting is **O(g log g)** in the number of gaps `g`. Normally `g` is much smaller than raw input rows; if something pathological produced a huge gap list, sort would dominate.

**Pure ABAP mitigations (no DB):**

- **Streaming / chunking:** if callers cannot hold 500k rows in one internal table, change the API to accept **iterator-style** processing (e.g. callback interface, `IF_SERIALIZABLE_OBJECT`, or repeated `SUPPLY_NEXT_CHUNK`) and merge into the same hashed table in batches — same algorithm, lower peak memory.
- **Memory:** ensure **one** canonical structure for actuals (hashed unique key) and avoid auxiliary copies; optionally use **shared memory / memory-mapped-style** segments only if the platform allows — still “no DB” but platform-specific.
- **Parallelization:** for huge baselines, partition the baseline table and run **parallel RFC / parallel tasks** (where permitted) each producing partial gap lists, then **merge-sort** streams by `(severity_rank, score, scope_item)` — keeps logic pure but adds orchestration complexity.

For typical fit-gap shapes (large actual, **small** baseline catalog), **the hashed actual index + single baseline pass** already scales linearly; the first thing to profile in practice would be **peak memory** during index build, not CPU.
