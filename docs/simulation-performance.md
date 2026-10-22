# Simulation performance audit

The first pass targets repeated CPU work during hunger emergencies. It preserves the
0.1-second simulation step, perception cadence, urgent decisions, route search budget,
food stock, and simultaneous combat resolution.

## Changes

- Survival deadlines now invert the existing piecewise starvation integral directly.
  This replaces 50 bisection iterations per agent per tick without changing damage.
- Internal physical queries reuse the barrier-revision cache. Public `segments()`
  still returns a deep copy, so callers cannot corrupt cached world geometry.
- Boolean sight queries stop at the first obstruction instead of constructing,
  sorting and describing every collision. Inspection still has detailed hit records.
- Conservative bounding checks reject distant wall segments before exact capsule
  tests in sight, movement and navigation. Exact collision geometry remains authoritative.
- Trusted simulation systems read the installed emergency profile instead of cloning
  a Resource for each eligibility check, candidate and contact calculation. They must
  never mutate `_profile`; `configure()` and public `profile()` retain defensive copies.
- Sight-range filtering uses squared distances and preserves negative-range behavior.

## Reproduction

Run `godot --headless --path . --script tests/benchmark_agents.gd` after editor import.
The benchmark builds the same seeded world for each population and density, with
20 wall segments, one finite food resource per three agents, nourishment 0.015 and
deprivation 0.5. It warms up five ticks, then measures 30 ticks of evolving behavior.
It prints median/p95 CPU time and a final digest of agent positions (rounded to
0.00001 cells), health, actions and intentions. It also times 10,000 survival estimates.
Compare the same script, engine and machine against the baseline revision c948aa6.
Timings are observations, never pass/fail thresholds or rendered FPS measurements.

## Phase 2 scaling changes

The history implementation adds spatial candidate indices, direct agent-ID lookup,
perception-phase reuse, bounded route caching, active-route reuse and a shared A*
expansion budget. Broad-phase sight also filters barriers once per observer; the exact
capsule tests remain authoritative. Observers receive independent belief snapshots,
and the observation caches are discarded before physical state can change.

Agent and object indices are refreshed after their respective mutations. Perception
phase caches cap sight rays at 8,192 and each of people, resources and observer barrier
sets at 2,048 entries. Route caching caps at 256 entries; history stores have per-agent
limits documented in [agent-history.md](agent-history.md). Detailed history text is
built only for the selected agent at 5 Hz. A* exhaustion returns DEFERRED, preserving
uncertainty rather than generating psychological setbacks. The decision order rotates
so early spawn IDs do not permanently monopolize that budget.

Dense neighborhoods still require many exact observations. Threat responses and
physical movement also cost work outside the A* budget. The renderer still draws all
actors; these measurements exclude GPU rendering. No universal frame-time guarantee
is implied by bounded memory or A* expansions.

## Verification

`tests/test_agent_query_equivalence.gd` checks survival deadlines against the damage
integral over nourishment, health and drain combinations. Random, stationary and
tangent sight/body queries are compared with an unpruned exact capsule-test oracle.
It also checks invalid sight, negative sight range, defensive geometry copies and
barrier-edit invalidation. The full suite covers food, rest, panic, emergency choices,
fight/flight, movement, doors and circular geometry.

## Observed results (Godot 4.6 stable, headless, 2026-10-19)

Baseline and optimized worlds used the same benchmark script, seed, warmup and tick
count. A repeat run produced the following times in milliseconds per simulation tick:

| Hungry agents | Layout | Baseline median / p95 | Optimized median / p95 | Median speedup |
|---|---|---:|---:|---:|
| 50 | Spread out | 38.784 / 45.926 | 9.685 / 10.642 | 4.0× |
| 150 | Spread out | 148.833 / 176.817 | 42.416 / 45.988 | 3.5× |
| 50 | Crowded | 202.372 / 223.760 | 38.548 / 41.433 | 5.2× |
| 150 | Crowded | 1720.666 / 2101.901 | 328.903 / 376.237 | 5.2× |

All four final behavior digests matched the baseline. This checks those scenarios'
rounded positions, health, actions and intentions; it is not proof of equivalence for
every possible world. Ten thousand survival estimates fell from 372.829 ms to 7.209 ms.
An earlier run also showed substantial improvements (3.3–5.3× in the larger workloads).
Measurements vary with host load and are not hardware-independent guarantees.

The 150-agent crowded emergency remains above the 100 ms budget for ten simulation
ticks per second. This patch improves that case but does not solve extreme-density
scaling. Full verification: 42/42 checks passed, plus independent code review with no
blocking findings. No rendered graphical/GPU benchmark was available.


## Phase 2 observations (Godot 4.6 stable, headless, 2026-10-22)

Same host, engine, script, seed, five warmup ticks and thirty measured ticks. Baseline
is the food-sharing branch (local `19c43cf`, remote `ef88e294`), not the older audit's
baseline. Baseline and final runs were sequential, without concurrent test workloads.

| Hungry agents | Layout | Before Phase 2 median / p95 (ms) | Phase 2 median / p95 (ms) |
|---|---|---:|---:|
| 50 | Spread out | 13.342 / 16.823 | 13.364 / 14.305 |
| 150 | Spread out | 48.692 / 51.298 | 48.031 / 52.065 |
| 50 | Crowded | 44.157 / 48.747 | 53.049 / 63.506 |
| 150 | Crowded | 345.722 / 399.188 | 273.197 / 326.620 |

The largest crowded case improved by about 21% at the median while adding history;
the 50-agent crowded case became about 20% slower. History deliberately changes dense
social behavior, so those two behavior digests differ and this is an end-to-end cost
comparison, not a pure microbenchmark of equivalent actions. The spread-out digests
match. Host load and the short evolving scenario affect timings. The 150-agent crowded
case remains over the 100 ms budget for ten ticks per second.

`benchmark_history.gd` processed 48,000 outcomes for twelve agents across 22,000 simulated
seconds. All stores remained capped. A twelve-agent update batch measured 1.247 ms
median early and 1.329 ms late (late p95 1.615 ms); largest JSON snapshot was 16,889 bytes.
JSON size is not a runtime heap measurement. Updates scan bounded stores rather than
the agent's lifetime history.

The complete suite includes controlled memory swaps, ablation, counterexperience,
shifted-clock restore, outcome producers, occluded witnesses, independent observations,
spatial-index oracle comparisons, barrier pruning against exact geometry, cache
invalidation, and deferred-work safety. Inspector behavior and small-viewport scrolling
are exercised headlessly; rendered visual/GPU validation is not available in this run.

Final verification: **49/49 checks passed** after review fixes. Independent review
identified two integration defects: unchanged executing routes after a learned detour,
and exact search-limit exhaustion misclassified as failure. Both were reproduced,
fixed and covered by failing-then-passing regressions before the final suite and
benchmark run.
