# Phase One: Polygons

Run `world/world.tscn`. The **Life** category provides Polygon, Food, Rest, and Move.
Click a cell to place a Polygon or resource at its center; right-click with that tool
to remove the corresponding kind. Drag a resource with Move to relocate it, preserving
its identity and remaining portions. Objects can share a cell in this first version.

Place food a few cells from a Polygon and watch it discover, approach, and eat.
Each food marker initially holds one serving and disappears when consumed.
Change `initial_stock` in its interaction resource to create larger finite piles. Add a resting place; an exhausted Polygon can
also rest on the ground, less efficiently. Rest sessions continue until fatigue is
at most 20%, unless another need interrupts them. Rest choices compare recovery rate
and travel time over the expected session, rather than one short recovery pulse. Open **Inspect Polygon**, then click a
Polygon to see hunger, fatigue, health, current action, remembered opportunities,
leading utility scores, recent outcome, and its current route. This does not command it.
Pause/Resume and 1×/2×/4× control simulation time; construction remains available paused.
The existing Spaces & doors inspector still operates doors and locks.

## Behavior

Nourishment falls over time; hunger is its complement. Urgency grows nonlinearly.
Below 10% nourishment, deprivation damages health. At zero health the agent stops
moving and releases interactions. Health-sensitive urgency can interrupt rest for timely
food, or motivate searching when no food is known. Prolonged inadequate nourishment
builds deprivation separately from current hunger; sustained feeding reduces it gradually.
Deprivation slows movement and narrows alternative consideration. Stable seeded caution,
persistence, and aggression influence decisions. There are no relationships, habits,
health regeneration, or day/night cycle yet.

Extreme deprivation can permit pursuit of living agents when timely ordinary food is
unavailable. This is contingent on traits and perceived risk, not automatic aggression.
Attacked agents escape or defend if no escape route is found. Strikes require contact
and clear line of sight, use a cooldown, and resolve simultaneously. Agents remember
observed positions only. Each death creates one finite corpse portion; only agents
eligible for extreme feeding may start eating it. Nutrition arrives after a completed
two-second interaction, never from a hit or kill. Corpse resources can be moved and
removed through the object API; a dedicated corpse editor tool is not included.

Inspect Polygon now includes urgency, accumulated deprivation, impairment, target, and
a reason for the last decision. Red-brown denotes pursuit/attack, amber escape/defense,
blue rest, green feeding; remains are faded triangles. These are simulation mechanics,
not clinical predictions. The evidence and numerical defaults are documented in the
emergency behavior specification. Configure a validated EmergencyProfile through
`simulation.configure(profile)`; `simulation.profile()` returns a defensive copy.

Sight has finite range and wall/closed-door occlusion. Beliefs contain last observed
locations, not live object references. An unseen moved object is not followed magically.
An empty remembered location is forgotten after inspection. Failed routes receive an
8-second retry delay, bypassed when traversal geometry changes. Known depleted food
remains unavailable until a later observation shows otherwise. Food and resting places
have capacity one; a reserved final portion cannot be consumed by another agent.
Objects opt into removal on depletion with `remove_when_depleted`; objects with any
remaining or unlimited capability stay in the world. Moving/removing a resource cancels its active users. Effects occur only on successful
completion; cancellation gives neither a portion nor its effects.

Agents use body-clearance pathfinding across straight/curved walls and doors. Unlocked
closed doors are opened on arrival, with the agent ID attached to the existing command;
locked doors block routes. Doors cannot close onto a living Polygon. Converted remains
are nonblocking resource objects; their former agent no longer occupies space.

## Code boundaries

- `agents/body_state.gd`: normalized physiology, deprivation history, and rates.
- `agents/emergency_profile.gd`, `emergency_assessment.gd`: validated settings and
  pure assessment of urgency, impairment, and remaining survival time.
- `agents/personality.gd`, `motivation_system.gd`, `option_evaluator.gd`: stable traits,
  need weights, bounded route evaluation, expected relief timing and decision reasons.
- `agents/threat_actions.gd`, `combat_system.gd`, `death_system.gd`: pursuit/escape,
  simultaneous contact strikes, and idempotent finite-remains creation.
- `agents/agent_motion.gd`: interpolation of the actual traveled segments and heading
  between simulation steps; drawing and picking use the same visual position.
- `agents/need_system.gd`, `decision_system.gd`: expected relief, travel penalty, options.
- `agents/perception_system.gd`: observations and negative sightings.
- `agents/polygon_agent.gd`: identity, body, snapshots, bounded recent event history.
- `agents/action_controller.gd`: interruption, travel, use, completion and failure.
- `agents/agent_navigation.gd`: geometry-only routes and door operations.
- `agents/agent_simulation.gd`: ordering and orchestration; independently headless-testable.
- `objects/object_definition.gd`: shared immutable configuration; instances own state.
- `objects/interaction_definition.gd`, `interaction_provider.gd`: capability configuration,
  capacity, stock, reservation/cancellation/completion. An object can offer multiple capabilities.
- `objects/object_store.gd`: IDs, queries, moves and removals.
- `objects/object_tool_handler.gd`: generic construction adapter, configured by `.tres`.
- `world/survival_view.gd`, `agents/agent_renderer.gd`: clock, inspection and visuals.

## Adding an object

Create a WorldObjectDefinition `.tres` with a unique definition_id and one or more
InteractionDefinition resources. Each capability defines its ID, duration, effects,
capacity and initial stock (-1 for unlimited). Instances get independent providers.
Register a ConstructionToolDefinition in a category and an ObjectToolHandler resource
with matching tool_id, operation `object`, and your definition in the world scene.
The menu, perception, and action dispatch need no new object-type branches.

Current effects are nourishment and fatigue. New physiological dimensions need explicit
body/need-system support; arbitrary scripts do not silently mutate an agent. More complex
interactions can specialize the provider contract by overriding
`InteractionDefinition.create_provider()` to return an InteractionProvider subclass. Object appearance is intentionally
minimal and can be replaced separately from behavior.

## Explicit prototype limits

- Live agents/objects are session-only. Existing structure serialization does not save them.
- Navigation searches a half-cell lattice in a start/goal box expanded by 12 cells,
  with a 4096-node budget. SEARCH_LIMIT/NO_ROUTE mean no route found within this search,
  not mathematical proof of inaccessibility. Very tight curved apertures can be missed.
- Exploration keeps a seeded heading, makes small direction changes on open ground,
  and tries larger turns when blocked. It remembers eight reached destinations to
  discourage immediate backtracking, but can revisit them when necessary. This is
  local search, not exhaustive global coverage or a guarantee of finding food.
- Polygons have wall clearance but do not yet collide with one another. Capacity controls
  resource contention; crowd avoidance and physical resource footprints are deferred.
- Fixed 0.1-second simulation updates, with per-frame movement interpolation and
  smooth heading changes. Interpolation adds one simulation step of display latency
  and follows waypoint segments to avoid cutting corners. At most eight updates
  run per rendered frame. Severe frame stalls slow
  simulation time rather than accumulating an unbounded catch-up backlog.
- Perception scans resources and nearby agents; navigation scans wall segments; intended for small
  populations initially. Each decision validates at most eight resource routes (two at
  maximum impairment), plus bounded threat/escape candidates. Spatial indexing and a
  shared population-wide route-work budget can come later.
- Ordinary food reservation ties still favor update order; combat strikes resolve
  together. Health does not regenerate and agents can die before a meal completes.
- Emergency parameters are game tuning, including the 30-second urgency window.
  Rest breaks are conservatively suppressed during urgent ongoing starvation;
  agents do not solve an optimal multi-action survival plan.

## Verification

Import scripts first, then execute `tests/test_*.gd` with Godot in headless mode.
New suites cover body/stock, navigation, integrated survival scenarios and tool/scene wiring.

Run the complete checks with:

```sh
python3 tests/run_tests.py /path/to/godot
```

## Natural emergency progression

The default extreme-feeding deprivation threshold is 0.35. With the current default
body rates, a fresh agent in a food-free world becomes eligible around 173 seconds,
with roughly 53% health remaining; without nourishment it still dies around 200 seconds.
The original 0.65 threshold exceeded the roughly 0.574 deprivation reached at death,
so extreme feeding was unreachable during a first uninterrupted starvation episode.
Eligibility permits consideration of corpse feeding or predation; traits, perceived
alternatives, and available targets still determine the actual choice. A lone agent in
an empty world has nothing to attack or eat and continues searching until death.
These numbers are game tuning, not scientific thresholds.

## Constraints, desperation, and fight or flight

Desperation is a motivation signal separate from accumulated deprivation and impairment.
Recent failed resource routes, blocked movement and failed exploration attempts increase
constraint pressure while nourishment is inadequate. Pressure decays after setbacks stop.
A comfortably fed agent does not become desperate merely because it is enclosed.
Successful nourishment reduces need pressure even while physical impairment remains.
Inspection shows both desperation and constraints.

Extreme feeding remains gated by starvation, absence of timely ordinary food, and
personality/risk assessment. High desperation can open that option before deprivation
alone would do so; zero aggression still rejects predation. Desperation changes willingness
to accept injury risk, not access to hidden food, opponents or exits.

Under direct threat, an agent compares its own reserves against observed opponent
condition and the number of known attackers. A stronger agent can defend itself without
being hungry; a vulnerable agent generally escapes when it can. Escape routes must gain
separation and avoid cutting through another known attacker, with bounded navigation
candidates including shorter nearby escapes. If no safe escape is found, the agent can
defend or guard. Defense strikes at contact and never pursues a withdrawn opponent.
Guarding alone does not renew hostility; actual incoming hits do, so confined agents
continuing to exchange damage can still fight to the death. Visible deaths clear obsolete
threats. Behavior uses coarse observed condition, not exact hidden enemy health.

These heuristics do not implement negotiation, surrender, combat formations, or freeze
responses. They do not establish clinical fidelity. The tuning remains centralized in
the emergency profile where rates and eligibility limits are configurable.

## Panic during blocked exploration

Panic is derived from existing constraint pressure (at least 50%) and desperation
(at least 65%); it is not another stored need or separate state machine. During
exploration it appears as 'Panicking' with the reason 'Panicking: searching for a way
out.' Comfortable failed searches continue to wait calmly. Panic does not bypass
ordinary food choices, threat responses, wall clearance, or predation eligibility.

Exploration tries four directions at distances 4, 1.5 and 0.5 cells, at most twelve
routes. Full-length movement or necessary backtracking is preferred; shorter steps
allow movement in cramped spaces. Resorting to short steps remains evidence of
constrained options, rather than proof that an exit is impossible. Recent-place memory
remains bounded. Panic retries failed exploration after 0.75 seconds and reconsiders
opportunities on the next fixed tick. A geometry change bypasses the wait immediately.
Pressure subsides when setbacks stop or nourishment relieves the urgent need; there
is no independent panic flag to clear.
