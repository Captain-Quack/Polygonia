# Walls, Doors, and Spatial Interpretation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This document proposes work; it does not authorize implementation or delegation.

**Goal:** Add editable walls and doors with structural region recognition and query contracts for future agents.

**Architecture:** WorldModel owns floors and sparse structures. A rectilinear arrangement derives regions and portals, while independent physical queries evaluate current barriers and possible door actions. Resource-driven construction tools propose atomic edits; social meaning remains outside the structural model.

**Tech Stack:** GDScript, Godot 4.7 project configuration, existing custom SceneTree test scripts, no added external dependencies.

**Spec:** ../specs/2026-10-14-walls-doors-design.md

## Global Constraints

- Use Godot 4.7 project configuration and GDScript; no new external dependencies.
- Existing Line strokes and floor outlines are not automatically walls.
- Structure coordinates use integer base cells within +/-1,000,000 on each axis.
- Walls are axis-aligned in v1; physical capsule radius is 0.05 base cells.
- Doors placed by the editor span one base cell, independent of zoom.
- Structure data schema version is 1; IDs are monotonic and never reused.
- Roof coverage is UNKNOWN until a coverage system exists.
- No ownership, room purpose, agent cognition, or full agent navigation is implemented here.
- Preserve commit(data, a, b, step, erase), preview_geometry(...), editor.data, and existing resource IDs for legacy handlers.
- Every failure rejects the complete proposed edit without mutation or success events.

## Review Focus

- Nested boundaries, dangling edges, and corner contacts must not yield overlapping or phantom rooms: Task 3.
- Opening a door and repainting floors must not invalidate room identity or topology: Tasks 3 and 4.
- Editing a wall that hosts a door must not leave unsupported apertures or change unrelated door IDs: Task 2.
- Coarse zoom, negative coordinates, and releasing a stale preview must commit exactly the validated target: Task 5.
- Physical body clearance, closing onto occupants, and invalid serialized data must fail safely: Tasks 2 and 4.

## File map and common record contracts

New code is grouped by responsibility. Keep the existing floors directory and resource locations; avoid unrelated renaming.

- world/world_model.gd: shared data owner; signal wiring and structure command entry point.
- construction/construction_context.gd: tool context including raw pointer, camera scale, and model.
- construction/construction_gesture.gd: raw/snap start and end, erase flag, frozen snap step.
- construction/construction_proposal.gd: valid/reason, preview dictionary, expected revision, command.
- construction/legacy_floor_command.gd: calls an existing handler against model.floors.
- structures/structure_data.gd: authoritative normalized runs, doors, IDs, versions, queries for records.
- structures/wall_run.gd and door_record.gd: typed records with copy/serialization helpers.
- structures/structure_command.gd: typed edit intent and validation/application/reversal service.
- structures/structure_change.gd: edit result and before/after revision data.
- structures/structure_codec.gd: versioned import/export and all-or-nothing validation.
- spatial/rectilinear_arrangement.gd: segment normalization, intersection splitting, half-edges.
- spatial/region_index.gd: faces with holes, point location, portals, identity and lineage.
- spatial/spatial_records.gd: Region, Portal, LocationResult, RegionChange records.
- spatial/physical_queries.gd: capsules, sweeps, visibility hits, and door crossing options.
- spatial/query_records.gd: BodyProfile, SweepHit, VisibilityHit, CrossingOption records.
- structures/structure_renderer.gd: world-space wall/door ink derived from committed geometry.
- structures/tools/: wall and door handler scripts/resources, icons, Structures category resource.
- world/spatial_inspector.gd: Inspect mode, selection, state controls, overlays, probe.
- tests/structure_fixtures.gd: shared deterministic geometry fixtures; no scene dependencies.
- tests/test_world_model.gd, test_structures.gd, test_regions.gd, test_spatial_queries.gd, test_structure_tools.gd: new suites.

All spatial query positions, radii, and distances are BASE-cell units. Convert at renderer/editor boundaries. Record IDs and revisions use int. Value records extend RefCounted; typed arrays use the corresponding nested record classes where practical. Do not expose internal mutable arrays to tools.

StructureChange fields: accepted: bool, reason: StringName, affected_bounds: Rect2, actor_id: int (0 for player/debug), previous_revision: int, revision: int, topology_changed: bool, barrier_changed: bool, traversal_changed: bool, before_state: Dictionary, after_state: Dictionary. Rejected changes keep before/after revisions equal. WorldModel.structure_changed(change) emits only for actual accepted mutations; idempotent no-ops return accepted without emission.

ConstructionProposal fields: valid: bool, reason: StringName, preview: Dictionary (existing paths/fills contract plus guides/markers/label), expected_revision: int, command: RefCounted. Commands expose execute(model: WorldModel) -> StructureChange; legacy floor commands return accepted state without changing structure revisions and preserve FloorData.changed behavior.

## Task 1: Shared model and backward-compatible construction seam

**Files:** Create world/world_model.gd, structures/structure_change.gd, and the four construction files above; modify floors/floor_editor.gd, floors/construction_tool_handler.gd, world/world.tscn; create tests/test_world_model.gd.

**Interfaces:** WorldModel initially owns floors and later adds structures. ConstructionContext fields: model, pointer_base: Vector2, cell_size: float, camera_scale: float, corner_radius_world: float. ConstructionGesture fields: raw_start/raw_end: Vector2, start/end: Vector2i, step: int, erase: bool. ConstructionToolHandler adds snap_policy() -> StringName (default visible_grid) and propose_edit(context, gesture) -> ConstructionProposal (legacy adapter). WorldModel.execute(command: RefCounted) -> StructureChange delegates to command.execute(self).

- [ ] Write test_shared_floor_identity: editor.data is model.floors and FloorRenderer.data is the same object. Write test_legacy_handler_adapter: a test-only handler receives model.floors, frozen step, endpoints, and erase exactly once; preview remains compatible.
- [ ] Run `godot --headless --path . --script res://tests/test_world_model.gd`; confirm failure because WorldModel/new methods do not exist.
- [ ] Implement shared ownership and adapter; keep ConstructionPreview node path. Define editor.data as a compatibility getter. Defer StructureData initialization until Task 2, without creating a second floor copy.
- [ ] Run the new suite and test_modular_tools, test_construction, test_circle_tools. Require zero failures and no script errors.
- [ ] Commit this independently working refactor as `refactor: share world state through construction context`.

## Task 2: Sparse structural data, atomic commands, and storage

**Files:** Create structures/structure_data.gd, wall_run.gd, door_record.gd, structure_command.gd, structure_codec.gd; extend WorldModel and the existing StructureChange record; create tests/test_structures.gd and tests/structure_fixtures.gd.

**Interfaces:**
- StructureData.get_walls() -> Array[WallRun], get_doors() -> Array[DoorRecord], get_door(id: int) -> DoorRecord; returned values are read-only copies.
- StructureCommand factories: wall(a: Vector2i, b: Vector2i, erase: bool), place_door(a: Vector2i, b: Vector2i), remove_door(id: int); each returns StructureCommand.
- StructureCommand.execute(model: WorldModel) -> StructureChange; restore(model, change, undo: bool) -> StructureChange checks expected current state before restoration. Revision counters always increase on restoration; IDs are never reassigned to unrelated entities.
- StructureCodec.encode(data: StructureData) -> Dictionary; decode(payload: Dictionary) -> Dictionary returning {valid, reason, data}, with data null on failure.
- StructureData has revision, topology_revision, barrier_revision, traversal_revision and next_id. Commands compute change flags once and WorldModel emits once.
- Fixtures.rectangle(model, min_corner: Vector2i, max_corner: Vector2i) executes four walls; fixtures.two_rooms(model) creates an 8x4 rectangle divided at x=4; fixtures.door_at(model, a, b) returns its created ID.

- [ ] Write test_wall_union_and_subtraction: reversed [0,0]-[8,0] and overlapping [4,0]-[10,0] normalize to one [0,0]-[10,0] run; erase [3,0]-[7,0] leaves two runs.
- [ ] Write test_door_host_edits: door [2,0]-[3,0] in [0,0]-[8,0] keeps its ID after wall extension/repaint; removal restores wall; erase [2,0]-[3,0] removes both. Use a programmatically wider aperture [2,0]-[4,0] to test that partial support erase [2,0]-[3,0] rejects with no signal.
- [ ] Write test_door_validation: reject unsupported, overlapping, adjacent, diagonal, out-of-range, and intersection-crossing placement; reject adding a crossing wall inside an existing aperture. Assert unchanged records/revisions on each rejection.
- [ ] Write test_structure_codec_and_restore: round-trip authoritative IDs/state, reject duplicate IDs and future schema, undo/redo door and wall operations, retain next-ID monotonicity after undo followed by a new branch of edits.
- [ ] Run test_structures and confirm the new assertions fail before implementation.
- [ ] Implement staging on copied authoritative structure records, invariant validation, and atomic replacement; normalize runs independent of door identities. No per-cell expansion. Implement serialization and internal restoration, not a global undo UI.
- [ ] Run test_structures and test_world_model; confirm idempotent paints emit no structural event.
- [ ] Commit as `feat: add transactional sparse wall and door data`.

## Task 3: Structural regions, portals, and identity

**Files:** Create spatial/rectilinear_arrangement.gd, region_index.gd, spatial_records.gd, tests/test_regions.gd; wire RegionIndex into WorldModel.

**Interfaces:** RectilinearArrangement.build(walls: Array[WallRun], doors: Array[DoorRecord]) -> Dictionary containing vertices, paired half_edges, and face boundary walks. RegionIndex.rebuild(data: StructureData) -> SpatialRecords.RegionChange; locate(point: Vector2) -> SpatialRecords.LocationResult; get_regions() -> Array; get_portals() -> Array. LocationResult includes kind (REGION/BOUNDARY/OUT_OF_RANGE), region_id, incident_region_ids. Region includes id, outer, holes, bounded, area, portal_ids. Portal includes id (door ID), region_a, region_b, a, b. RegionChange includes preserved_ids, removed_ids, created_ids, overlap_links, and exterior_transition_ids.

- [ ] Write test_rectangle_and_floor_independence: rectangle (0,0)-(4,3) gives bounded area 12 plus exterior 0; adding floor polygons/decorative lines produces no topology rebuild or region changes.
- [ ] Write test_open_door_identity: placing a door on an existing rectangle changes portals but preserves its region ID. Later Task 4 extends this fixture with state changes.
- [ ] Write test_faces_with_holes: outer (0,0)-(10,10), inner (3,3)-(7,7) produce finite areas 84 and 16, with (1,1) in annulus and (5,5) in inner region. Add a third nested ring and check area conservation.
- [ ] Write test_degenerate_contacts: dangling interior segment produces no extra room, complete T partition splits a room, X intersection yields expected partitions when enclosed, touching corner loops remain separate, point on a wall returns BOUNDARY. A door in an isolated wall has equal incident region IDs.
- [ ] Write test_identity_lineage: two_rooms split/merge changes create explicit positive-area lineage, unchanged distant rectangle ID persists, collinear segment splitting alone preserves IDs, touching faces have no overlap lineage.
- [ ] Write test_sparse_large_coordinates: rectangle (-500000,-2)-(500000,2) uses four normalized runs and bounded finite-size arrangement, with area 4000000; translating disconnected rectangles far apart does not allocate intervening cells.
- [ ] Run test_regions and confirm failures; then implement the spec's half-edge arrangement, face component grouping, point location, canonical signatures, and lineage.
- [ ] For overlap lineage use bounded rectilinear face intersection by sweeping the union of old/new vertex y-levels, intersecting interior x-intervals at slab midpoints and accumulating width times height; subtract holes through winding/parity intervals. This avoids implementing arbitrary polygon clipping or rasterizing area.
- [ ] Run tests; use deterministic generated arrangements and a small finite four-neighbor raster oracle away from boundaries to cross-check region membership on small fixtures. The oracle treats door apertures as structural separators.
- [ ] Commit as `feat: derive rooms and portals from structural boundaries`.

## Task 4: Door transitions and physical query contracts

**Files:** Extend StructureCommand and WorldModel; create spatial/physical_queries.gd, query_records.gd, tests/test_spatial_queries.gd.

**Interfaces:** StructureCommand.door_action(id: int, action: StringName, actor_id: int = 0). WorldModel.occupancy_query: Callable receives proposed closing capsule and returns bool occupied; default false. PhysicalQueries.sweep(from: Vector2, to: Vector2, radius: float) -> QueryRecords.SweepHit; visibility_hits(from, to) -> Array[QueryRecords.VisibilityHit]; crossing_option(door_id: int, profile: QueryRecords.BodyProfile) -> QueryRecords.CrossingOption. BodyProfile fields radius and can_open_doors. CrossingOption fields kind, reason, door_id, action_cost (0 for PASS; configurable positive open cost, default 1 simulation-time unit). Hits include valid and reason, hit bool where appropriate, position, normal, entity_id, barrier_revision.

- [ ] Write test_door_actions: OPEN succeeds unlocked, LOCK while open rejects, CLOSE then LOCK succeeds, OPEN locked rejects, UNLOCK succeeds. Missing IDs and unknown actions reject. Check exact model/topology/barrier/traversal revision deltas from spec.
- [ ] Write test_crossing_options: open doorway gives PASS for radius 0.2; closed/unlocked gives OPEN_THEN_PASS to opener and BLOCKED otherwise; locked blocks both; radius 0.5 cannot pass a one-cell aperture with radius-0.05 jamb capsules.
- [ ] Write test_swept_clearance: wall blocks crossing including high-speed segment sweeps; diagonal movement cannot cut through a closed corner; open aperture permits centered small body; out-of-range or negative-radius input returns explicit invalid result.
- [ ] Write test_visibility: opaque wall and closed door hit; open aperture permits ray; ray grazing capsule tangency counts as blocked consistently. Order multiple hits by distance then entity ID.
- [ ] Write test_occupied_close_and_topology: callback reporting overlap rejects close without state/event changes; opening/closing never invokes region rebuild and preserves region ID; locking invalidates traversal but not visibility revision.
- [ ] Run test_spatial_queries for initial failure; implement segment/capsule geometry and state transitions. No live agents or navigation mesh are required. Validate against independent analytic axis-aligned fixtures.
- [ ] Run test_spatial_queries, test_regions, and test_structures; commit as `feat: expose door actions and physical boundary queries`.

## Task 5: Registered construction tools and rendering

**Files:** Create structures/tools/wall_handler.gd, door_handler.gd, associated .tres resources and icons, structures/tools/structures_category.tres, structures/structure_renderer.gd, tests/test_structure_tools.gd; modify handler context/editor and world.tscn.

**Interfaces:** Both handlers override propose_edit(context, gesture); wall snap_policy returns visible_grid, door returns host_base_grid. StructureRenderer consumes WorldModel and cell_size; draws from physical geometry rather than interpreting floor pixels. New resources register through existing category/handler arrays.

- [ ] Write test_tool_registration: Wall and Door appear through resources; existing custom handler still works; no tool-name branch is required in menu/editor.
- [ ] Write test_wall_gesture: dominant-axis reversed/negative gestures, fixed visible snap interval, zero-length no-op, right-drag erase and preview/commit agreement.
- [ ] Write test_door_targeting: wall projection within 10 screen pixels, fixed one-cell width at multiple zooms, half-cell ties toward smaller start, intersection ambiguity rejection, unsupported target remains invalid instead of jumping elsewhere. Release places at most one door.
- [ ] Write test_stale_preview: host changes after preview; release revalidates and refuses an unsupported aperture. Invalid placement leaves geometry and IDs unchanged.
- [ ] Write test_cancellation_and_rendering: Escape, focus loss, tool switch, release over UI cancel; physical thickness in world coordinates is unchanged across zoom; floor/line visuals still render independently.
- [ ] Run test_structure_tools for initial failure; implement shared proposal presentation, raw-pointer context, handler-specific snapping, renderer, and resource registration.
- [ ] Run test_structure_tools and all existing construction/menu suites; commit as `feat: add grid-snapped wall and door construction tools`.

## Task 6: Inspectable spaces and integrated delivery

**Files:** Create world/spatial_inspector.gd; extend tests/test_structure_tools.gd; modify world/world.tscn, README.md, docs/verification.md.

**Interfaces:** Inspector exposes enter_inspect_mode(), select_at(point_base: Vector2), selected_door_id, selected_region_id. It invokes WorldModel.execute for actions and reads RegionIndex/PhysicalQueries. Construction mode cancels inspection pointer actions; Inspect mode cancels active construction gestures. Overlay toggles are local UI state.

- [ ] Write test_inspection_input_ownership: inspecting never paints, construction never toggles doors, UI clicks do not pan or commit; selected deleted doors clear safely.
- [ ] Write test_inspection_truth: bounded region display has coverage Unknown and no owner/home classification; door controls reflect actual state and rejection reasons; ray/body probes match direct query results.
- [ ] Run tests for initial failure; implement inspector, region/portal overlays, and obstruction probe. Keep debug state controls visibly distinct from future agent decisions.
- [ ] Run import with `godot --headless --path . --editor --import --quit` and main-scene startup with `godot --headless --path . --quit-after 5`.
- [ ] Run every tests/test_*.gd suite, inspect each exit code and reported failure count, then `git diff --check`. Existing SceneTree suites may print failures without reliable nonzero exit codes; verify both.
- [ ] Benchmark arrangement rebuilds for 100, 500, and 1000 wall runs, plus distant/huge sparse fixtures. Record engine/hardware, counts, memory observations, and timing without promising a hardware-independent threshold. Verify door toggles and floor painting trigger zero arrangement rebuilds.
- [ ] Perform graphical Godot 4.7 checks if available: wall junctions, door aperture and state readability, local snapping guide at coarse zoom, invalid placement feedback, room overlays with holes, UI scaling, and all three original tools. If unavailable, explicitly leave visual/4.7 acceptance unverified.
- [ ] Update README and verification log with actual results, controls, coordinate/shape limitations, and deferred capabilities. Commit as `feat: inspect structural spaces and door behavior`.

## Completion and later work

The completed milestone must let a person construct two rooms, insert a door, inspect distinct region identities, toggle/lock it, and verify passage and sight queries without any agent AI. Removing the connecting wall merges structural space and emits lineage. The same scene can then become the first agent experiment.

Later projects consume these interfaces: agent perception and memory; detailed navigation including executable door actions; shared-use expectations and place attachment; roof coverage/weather; save/load of whole worlds including agent anchors; full construction undo; windows/materials; diagonal/curved walls; autonomous building. None should require making a physical region the authoritative owner of a social meaning.

## Plan self-review

- All design requirements are assigned to Tasks 1–6, including legacy handlers, sparse coordinates, aperture support, region identity, state/capability separation, input ownership, revisions, serialization, and evidence-based verification.
- Topology is the highest algorithmic risk. Complete and test Task 3 before polishing tools; do not substitute cell-area flood filling to make fixtures pass.
- Stable door IDs are authoritative; runtime room IDs are derived. Future whole-world persistence must remap agent anchors explicitly.
- This is a design and plan only. No implementation tests have been run for the proposed functionality.

## Implementation status — 2026-10-15

Tasks 1–6 implemented on `feature/walls-doors`; detailed checks are grouped into seven new suites rather than one script per checklist assertion. The initial checkbox list above is the original test plan. Actual validation evidence and remaining graphical acceptance limits are in `docs/verification.md`.

Shared WorldModel, sparse commands/codec, region arrangement and lineage, physical queries, resource-driven tools, and inspector are integrated. All 14 suites, import and startup pass. Randomized region oracle and 100/500/1000-run benchmarks complete. Review fixes for boundary incidence, restore rejection revisions and long-sweep precision each have failing-before/passing-after regression evidence.

Implementation rulings: validated dictionary records avoid cyclic resource dependencies; full sparse topology rebuild is retained for this prototype with documented quadratic cost; social places remain separate from structural enclosure. Godot 4.7 and graphical acceptance remain unverified on this host. No agent simulation, roofs or global undo/save interface added.
