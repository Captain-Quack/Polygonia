# Walls, doors, and spatial interpretation — proposed design

Status: proposed design for review; implementation is not started. Date: 2026-10-14 (America/Chicago).

## Intent and scope

Polygonia is a minimal graphical, textually rich simulation in which the player changes the environment and agents develop uses, habits, attachments, and social expectations. Agents initially use the world they are given; autonomous construction is a later possibility. No LLM is required by this design. Physical room recognition must not assign ownership, room function, household membership, or social permission.

This milestone delivers editable straight walls and doors, physical boundary queries, structural room recognition, and a development inspector. Agent cognition, complete agent navigation, roofs, weather, acoustics, autonomous construction, and social ownership remain later milestones. Interfaces are provided for those consumers without implementing speculative subsystems.

Recommended defaults below are proposals, not previously accepted requirements. In particular, ordinary walls are horizontal/vertical in this milestone; circular floors do not automatically generate curved walls.

## Existing project and integration constraint

The inspected checkout is commit ab2ac90, feature/circle-construction. It contains Square and Circle editing shared floor geometry, and Line editing an independent array of axis-aligned Vector4i segments in FloorData. ConstructionPreview uses floors/floor_editor.gd and currently owns FloorData. Handler commit(data, a, b, step, erase) and preview_geometry(...) are resource-driven and tested with third-party handlers. WallRenderer and Inspector are scene placeholders. Project metadata specifies Godot 4.7, while previous automated validation used 4.5.1.

Move world ownership into a shared WorldModel. Keep current FloorData, Line semantics, handler resources, and the editor.data compatibility accessor. Do not silently turn existing Line strokes or floor outlines into collision barriers. Add a Structures category containing Wall and Door; reserve a future explicit conversion operation for old lines.

Use Godot 4.7 project configuration and GDScript; no new external dependencies. Validate with the available engine and report its exact version; do not claim Godot 4.7 or graphical verification unless actually performed.

## Three different descriptions of space

1. Structural regions: geometric partitions made by wall centerlines and explicit doorway separators. A region can be bounded or part of the unbounded exterior.
2. Physical conditions: actual barrier shapes, door state, passage width, visibility, and eventually roof/weather exposure.
3. Agent places and beliefs: remembered locations, routine use, attachment, accepted claims, privacy expectations. These are future agent-owned data referencing spatial anchors and historical region identities.

A doorway remains a structural separator when open. Navigation and visibility respond to its physical state. Removing its supporting wall changes the structural partition. A naked wall gap is not automatically inferred to be a doorway: it connects the structural regions. An explicit permanently open opening could later preserve a separator without a door leaf.

Do not equate one connected navigation component with one room. A door can connect rooms; a thin room can be structurally connected but too narrow for an agent's body.

## Inside and outside

Track bounded versus exterior-connected structural space now. It supports entrances, bottlenecks, inspection, and later spatial reasoning, without assigning social meaning.

Reserve a distinct coverage interface with UNKNOWN, UNCOVERED, and COVERED values. With no roof system, coverage is UNKNOWN everywhere. Do not infer roofs from floors or closed wall loops, and do not expose an authoritative indoor boolean yet.

Examples:

| Situation | Structural region | Coverage | Immediate access |
|---|---|---|---|
| Closed room | Bounded | Unknown until coverage is modeled | Doors determine options |
| Same room, door open | Same bounded region and ID | Unchanged | Opening permits suitable bodies |
| Walled courtyard | Bounded | Uncovered once explicitly represented | Entrances determine options |
| Canopy without walls | Exterior | Covered once explicitly represented | Open on its sides |
| Wall with an unframed gap | Connected through gap | Independent | Depends on clearance |

Weather, ventilation, sound, visual exposure, and social privacy are separate future computations. Exterior connectivity through an open doorway does not mean every interior point receives rain or becomes public space. Future agent evaluations combine these features with personal experience.

## Authoritative structure model

StructureData stores sparse axis-aligned wall runs and independent DoorRecord objects in base-cell coordinates. It never allocates a cell for every covered square or empty square in the world.

WallRun fields: stable monotonic ID, integer endpoints, material ID. Initial material is solid and opaque. Canonicalize endpoint ordering. Union overlapping/touching collinear runs of identical material. Different materials require an explicit replacement operation in the future; only one material is available now. Intersections are legal and participate in the derived arrangement.

DoorRecord fields: stable monotonic ID, integer aperture endpoints, CLOSED or OPEN state, locked boolean. Width is one base cell for editor placement, represented by endpoints rather than a hardcoded width in storage. The aperture is anchored by coordinates, not by a mutable wall-run index or ID. Initial placement is closed and unlocked.

A door overlays a continuously supported interval of wall. The host wall remains authoritative beneath it; physical geometry substitutes the door leaf for that interval. Door removal restores solid wall. Wall erasure covering the complete aperture removes the door and wall together. Erasure that would leave only part of a door unsupported is rejected atomically. Painting matching wall over an existing door preserves it.

Reject unsupported apertures, zero-length apertures, overlapping apertures, and perpendicular wall intersections strictly inside an aperture. Reject adding a wall across an existing door's interior. Intersections at aperture endpoints are allowed structurally, but physical clearance still determines passage. Adjacent apertures sharing an endpoint are rejected in v1 to preserve a wall jamb and unambiguous picking.

IDs are not reused. Coalesced/split wall IDs are mapped by edits where needed; door IDs survive unrelated host normalization. Structure schema version 1 serializes authoritative walls, doors, states, material IDs, and next-ID counters. Derived regions and rendering caches are rebuilt. This is a structure serialization contract, not a claim that the entire game has save/load.

## Geometry and room recognition

Use a sparse planar arrangement, rather than a flood fill over all base cells. This matches the existing practically unbounded graph paper and compact floor storage. The initial arrangement is rectilinear and exact at integer endpoints.

Topology recipe:

1. Normalize collinear wall intervals. Include door aperture endpoints as split points; their host intervals remain structural separators in either state.
2. Split segments at every intersection and endpoint-on-segment contact. Coalesce duplicate derived edges. Only create vertices at relevant coordinates.
3. Build paired directed half-edges. Sort outgoing directions in a documented coordinate convention (convert Godot y-down to mathematical y-up during orientation calculations).
4. Walk face boundaries by selecting the next directed edge around each vertex consistently. Track directed edges, not just visited vertices. Bridges and dangling walls can appear twice on one face walk; they do not create rooms.
5. Group boundary components by containment to form faces with holes and identify the single unbounded face. Nested rings must not produce overlapping room areas. A standalone wall inside a room changes barriers but does not create another room.
6. Derive a portal for each door. Sample the two sides of its aperture midpoint to assign incident faces. A door in a freestanding wall can have the same region on both sides: retain its physical interaction but do not claim it separates two rooms.

Use exact integer cross products within a validated coordinate envelope of +/-1,000,000 base cells; reject structure edits outside it with an explicit message. Use local origins and compensated/checked area accumulation to avoid overflow and floating-point cancellation. This envelope protects structure computation; it does not promise the renderer retains subcell precision at its extremes. Existing floors retain their current coordinate behavior. Distance-from-origin graphical limits remain documented.

For v1, rebuild the complete arrangement after a committed structural edit, not while dragging or when opening a door. Pairwise intersection detection may initially be O(E^2); memory and region computation must depend on geometry complexity, not enclosed area or coordinate separation. Benchmark before selecting a spatial-index optimization. Keep the arrangement builder behind an interface so intersection acceleration is replaceable.

Point location returns REGION, BOUNDARY, or OUT_OF_RANGE, with incident region IDs for boundary points. The unbounded exterior is region 0, not an absent result. Never choose a side arbitrarily for a point exactly on a wall. Holes, disconnected buildings, T/X joins, dangling partitions, corner contacts, and narrow corridors are required cases.

Region records include ID, outer ring, hole rings, incident portals, boundedness, and derived area. Keep unchanged regions' IDs by a canonical boundary signature that ignores incidental collinear edge splits. Changed regions get new IDs and lineage links based on positive-area overlap with former bounded regions; touching alone is insufficient. Emit old/new IDs and overlap areas. Exterior 0 persists and is treated explicitly in transitions rather than assigned infinite overlap values. Remembered places must use anchors/history as well as region IDs. A new room is not automatically a new home.

Arbitrary diagonal or curved walls are a later geometry-kernel extension. Keep consumers on region, barrier, and portal queries so they do not depend on compass directions. Do not promise that replacing the rectilinear intersection kernel is cost-free. Circle floor boundaries remain purely floor geometry in this milestone.

## Doors: state, action, and permission

Door state affects physical access and visibility, not structural partitioning. Implement OPEN, CLOSE, LOCK, and UNLOCK commands. LOCK is valid only while closed; OPEN fails while locked; locking does not imply social ownership. Unlock is a debug/player operation initially; credentials and agent authority are future concerns.

For traversal evaluation return PASS, OPEN_THEN_PASS, or BLOCKED, plus door ID, reason, and action cost. A closed unlocked door returns OPEN_THEN_PASS only if the supplied physical capability profile permits opening doors. A locked door is blocked in this version. Later capability profiles can add unlocking and other actions without replacing the query contract.

An agent must still decide whether to use a physically possible option. Social permission, fear, loyalty, and respect for a claim belong in its decision layer. Requesting permission and waiting are future social actions, not collision flags.

State changes run through the command service. A close operation checks the authoritative occupancy callback against the closing barrier and rejects with OCCUPIED if an agent overlaps it. The no-agent world supplies an empty callback; tests supply bodies. Future animated opening/closing must change passage at a defined completion event; this milestone changes states atomically and uses no collision-bearing swing animation.

## Physical queries and presentation

Walls and closed doors have a fixed logical thickness of 0.1 base cells, represented as centerline capsules of radius 0.05. Open apertures omit the leaf capsule. Agent motion uses swept-disk intersection with those capsules; opening-end clearance is therefore checked geometrically and is not merely a room-graph connection. Ink texture may vary, but zoom never changes physical thickness. An illustrative swing arc is decorative.

Provide exact segment/swept-disk queries and ordered visibility intersections independently of any agent scene. V1 barriers are opaque; open doors do not occlude their aperture. Return hit position, normal, barrier/door ID, and geometry revision. Objects, windows, materials with transmission, and sound are future extensions. Do not expose a fictitious numeric acoustic simulation now.

Do not use NavigationObstacle2D avoidance alone as the authority for blocked paths. Godot distinguishes avoidance from navigation mesh/path computation. A future navigation adapter must consume the same physical barriers and explicitly represent door actions. A sparse room/portal graph supplies high-level routes, not collision-safe detailed paths or complete routes through the unbounded exterior. Full agent navigation is deferred; the query tests and inspector prove the contract now.

Agent knowledge must eventually be updated by perception/communication events. WorldModel events are authoritative simulation facts for systems; they must not be broadcast into every agent's mind. Event records include location, actor when present, door/structure IDs, previous/new state, and revision so a future perception service can filter them.

## Construction interaction

Wall: left-drag uses the current dominant-axis convention and visible grid interval, frozen for the gesture. Right-drag erases the corresponding centerline interval. A click without length is a no-op. Preview displays the exact edit proposal and invalidity reason. T/X joins and overlaps normalize on commit. Long strokes are compact runs.

Door: placement targets an existing wall under the pointer, with a fixed one-base-cell aperture. It uses base-grid snapping along that wall, not a width that changes with zoom. Display a local one-cell guide and exact aperture preview. Pick within 10 screen pixels, choose nearest wall, and show ambiguity as invalid when equally close at an intersection. Choose the nearest legal integer start to pointer projection minus half the width; ties choose the smaller coordinate. Do not silently relocate an invalid aperture to a different opening. Left release commits one placement; right release removes the targeted door. A drag previews the release target and never paints a row of doors.

Add a handler snap policy so this difference is defined by tool resources rather than tool-name branches in the editor. Preserve existing paint cancellation on Escape, tool change, focus loss, and release over UI, plus camera input ownership. Pointer context must include unsnapped base coordinates for door hit testing; rounding too early loses which wall was targeted.

Add an Inspect mode separate from construction. Selecting a door offers Open/Close and Lock/Unlock debug controls. Selecting space shows structural region ID, area, boundedness, portal neighbors, and coverage = Unknown. Optional overlays display region colors, portals, and a probe segment with physical obstruction/visibility results. No agent home labels are inferred.

## Commands, revisions, and forward compatibility

WorldModel owns FloorData and StructureData. A ConstructionContext supplies model, pointer/gesture coordinates, snap settings, and selected-tool configuration. Add an optional propose_edit(context, gesture) interface; its default adapter preserves legacy preview_geometry and commit calls against world.floors. New structure handlers return a validated proposal/command; no wall/door branch belongs in the menu.

Structure commands validate before mutation, commit atomically, and publish once. Return structured failure reasons. Maintain model revision (all structure changes), topology revision (geometry/aperture membership), and barrier revision (physical geometry/state). Open/close changes barrier revision only beyond the model revision; lock changes model/traversal availability but not occlusion geometry. Include a separate traversal revision so lock changes invalidate route options.

Proposals carry the revision against which they were validated. Revalidate on release if it changed; never commit stale host geometry. Rendering, topology, and perception consumers read committed state, not partially applied edits.

Use commands for player edits and debug door actions now. Future agents may request permitted door actions and eventually construction through the same validation layer. Actor intent/permission checks remain outside geometry validation. Store before/after structure state and emitted deltas for restoration tests; provide structure command undo/redo internally. Do not expose a global Ctrl+Z that silently ignores floor edits until floor commands participate in the same history. A complete undo UI and world save/load are separate features.

Structure serialization validates all invariants before replacing a model. Reject unknown future schema versions without mutation. Rebuild topology, retain authoritative door IDs, and emit a world-replaced notification rather than pretending load is a series of perceptible construction events. Derived region IDs are runtime IDs; later whole-world saves containing agents must explicitly restore their spatial anchors and remap runtime IDs.

## Implementation milestones

1. Shared world ownership and backward-compatible construction context.
2. Sparse wall/door records, atomic edits, serialization, and internal reversal.
3. Structural arrangement, regions/holes/exterior, portals, and identity lineage.
4. Door state machine and physical/traversal/visibility queries.
5. Registered Wall/Door tools, fixed-width door snapping, rendering, and inspection.
6. Integrated regression, topology stress checks, and actual graphical verification.

Each milestone has an independent test suite. Full agent brains and room purposes are not prerequisites.

## Acceptance scenarios

- Four walls produce one bounded region plus exterior even with no floor paint.
- Floor circles, floor holes, and decorative lines alone do not create rooms or block motion.
- Door placement/open/close/lock preserve bounded room identity; removal restores solid wall.
- A closed unlocked door offers OPEN_THEN_PASS to an opener and blocks a non-opener; a locked door blocks both until unlocked.
- Doorway clearance and swept motion prevent corner cutting and passage by an oversized body.
- Removing a complete wall/door interval opens a structural gap; partial aperture support edits are rejected without a changed signal.
- Two connected rooms stay distinct across an open door; a naked gap merges them.
- Nested rectangles yield an inner region, an annular region, and exterior, with no double-counted area.
- Isolated wall segments and dangling interior walls create no extra rooms, but still block relevant motion/sight.
- A T partition can split a room; a point contact does not create a traversable gap.
- Closing on an occupied aperture fails with a reason and does not change state.
- Region edits publish lineage; unchanged rooms and doors retain IDs.
- Camera zoom, floor edits, and door opening do not rebuild structural topology.
- A rectangle one million cells wide and disconnected distant buildings use storage proportional to boundary complexity, not area/distance; render limitations are separately disclosed.
- Existing seven suites and custom legacy handler registration remain functional.
- Negative coordinates, cancellation, invalid previews, serialization rejection, and internal undo/redo preserve invariants.

## References

- Godot navigation obstacles: https://docs.godotengine.org/en/4.5/tutorials/navigation/navigation_using_navigationobstacles.html
- Godot AStarGrid2D: https://docs.godotengine.org/en/4.5/classes/class_astargrid2d.html
- Prior project design: docs/superpowers/specs/2026-10-14-circle-construction-design.md
- Prior social simulation discussion in this conversation establishes separate physical regions, agent places, and beliefs; this design is our proposed engineering synthesis, not a scientifically validated model of society.
