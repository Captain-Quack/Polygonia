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

## Remaining costs

- Agent perception still visits every other agent each tick. A spatial candidate index
  is the next scaling improvement for large populations, particularly spread-out ones.
  It must preserve observer-specific sight ranges, fresh combat sightings, remembered
  targets and deterministic iteration order.
- Urgent agents assess routes every tick; threat responses can test eight escape
  routes against several attackers. Dense emergency scenes remain substantially more
  expensive than ordinary activity. Any route reuse needs explicit start/goal, radius
  and traversal revision handling, plus accurate remaining distance estimates.
- Resource perception scans all objects, and depletion cleanup scans the store each
  tick. A resource index and event-driven depletion are candidates for worlds with
  many objects; movement, removal and reservation visibility must stay correct.
- Agent lookup is linear. An ID map could help combat-heavy runs, but requires a
  consistent ownership boundary for the currently exposed agent array.
- The scene adapter refreshes inspection text and draws all actors every frame.
  View culling and cached geometry/styles are possible presentation improvements.
  This audit measures headless CPU time, not GPU/frame rendering cost. Blood effects
  remain bounded independently of population.

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
