# Phase One: Polygons

Run `world/world.tscn`. The **Life** category provides Polygon, Food, Rest, and Move.
Click a cell to place a Polygon or resource at its center; right-click with that tool
to remove the corresponding kind. Drag a resource with Move to relocate it, preserving
its identity and remaining portions. Objects can share a cell in this first version.

Place food a few cells from a Polygon and watch it discover, approach, and eat.
Food initially holds eight portions. Add a resting place; an exhausted Polygon can
also rest on the ground, less efficiently. Open **Inspect Polygon**, then click a
Polygon to see hunger, fatigue, health, current action, remembered opportunities,
leading utility scores, recent outcome, and its current route. This does not command it.
Pause/Resume and 1×/2×/4× control simulation time; construction remains available paused.
The existing Spaces & doors inspector still operates doors and locks.

## Behavior

Nourishment falls over time; hunger is its complement. Urgency grows nonlinearly.
Below 10% nourishment, deprivation damages health. At zero health the agent stops
moving and releases interactions. This phase includes no attacks, cannibalism,
corpse consumption, relationships, habits, personality, or day/night cycle.

Sight has finite range and wall/closed-door occlusion. Beliefs contain last observed
locations, not live object references. An unseen moved object is not followed magically.
An empty remembered location is forgotten after inspection. Failed routes receive an
8-second retry delay, bypassed when traversal geometry changes. Known depleted food
remains unavailable until a later observation shows otherwise. Food and resting places
have capacity one; a reserved final portion cannot be consumed by another agent.
Moving/removing a resource cancels its active users. Effects occur only on successful
completion; cancellation gives neither a portion nor its effects.

Agents use body-clearance pathfinding across straight/curved walls and doors. Unlocked
closed doors are opened on arrival, with the agent ID attached to the existing command;
locked doors block routes. Doors cannot close onto a Polygon, including a dead one.

## Code boundaries

- `agents/body_state.gd`: normalized physiology and rates.
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
- Exploration is deterministic local wandering, not exhaustive global search of an
  unbounded world. It does not promise to discover arbitrarily distant food.
- Polygons have wall clearance but do not yet collide with one another. Capacity controls
  resource contention; crowd avoidance and physical resource footprints are deferred.
- Fixed 0.1-second updates, at most eight per rendered frame. Severe frame stalls slow
  simulation time rather than accumulating an unbounded catch-up backlog.
- Perception scans resources and navigation scans wall segments; intended for small
  populations initially. Spatial indexing and a shared route-work budget can come later.

## Verification

Import scripts first, then execute `tests/test_*.gd` with Godot in headless mode.
New suites cover body/stock, navigation, integrated survival scenarios and tool/scene wiring.

Run the complete checks with:

```sh
python3 tests/run_tests.py /path/to/godot
```
