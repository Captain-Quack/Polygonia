# Verification — 2026-10-13

Engine: Godot 4.5.1 stable Linux x86_64.

- Headless editor import: passed, no script errors.
- Headless main-scene startup (5 frames): passed.
- tests/test_world.gd: 0 failures. Checks negative cell mapping, fixed construction units, independent step uniforms, wheel input over GUI, cursor anchoring through actual viewport transforms, maximum zoom, reset position/zoom, and reversed zoom bounds.
- Test first run failed because the World scene did not exist. After implementation the suite passed.
- Independent code review found scroll events passing through the reset button. Added a failing input-routing regression test, set mouse_force_pass_scroll_events=false, and verified the whole suite passed.
- Independent review found no further important defects; adjacent grid level continuity reviewed mathematically.

Limitation: no graphical runtime/editor screenshot was obtained. A local virtual-display attempt failed because the host cannot open display sockets. Headless tests do not establish shader compilation on an actual GPU, visual appearance, or the editor preview's visual correctness. Check these on first opening:
1. Ivory paper and subtle grid fill the viewport during resize/pan.
2. Colors and step counts update in the 2D editor Inspector.
3. Zoom across several levels: lines should crossfade without abrupt jumps.
4. Use unequal step counts, then pan through negative coordinates.
5. Smooth wheel zoom stays anchored at the cursor; dragging stops on focus loss.

No game construction, agents, persistence, or origin rebasing is implemented in this milestone.

## Floor tools update
Godot 4.5.1: fresh editor import and runtime startup passed. Existing world suite and new floor suite both report 0 failures. New checks cover interior erasure, preservation outside erasures, repaint, non-overlapping region storage, huge compact fills, reverse rectangle drags, dominant-axis line shapes, coarse snap selection, and exclusive toolbar state. Graphical inspection remains unavailable on this host; the supplied reference images informed the procedural button and ink styling.

## Modular construction tools — 2026-10-14

Implemented against current main `d0de78d`, preserving its Godot 4.7 project settings and scene metadata. Validation used available Godot 4.5.1 stable; Godot 4.7 and graphical Inspector interaction were not tested.

- Headless editor import registers ConstructionToolDefinition, ConstructionCategoryDefinition, ConstructionToolHandler, and both concrete handlers without script errors.
- All six suites pass with zero failures: world, floors, construction, shape_geometry, menu_layout, modular_tools.
- Main-scene headless startup (5 frames) and `git diff --check` pass.
- New resource-existence checks failed before implementation and pass afterward.
- New tests demonstrate a third tool in a second category, registration, commit dispatch, fallback labels, unsupported tools, exclusive selection, cancellation, live edits, invalid IDs, ordering, repeated rebuild/collapse, wrapping and viewport resizing.
- Independent review identified legacy fallback array edits failing to refresh. A regression test reproduced the failure; effective-category snapshots fix it. Resource changed signals refresh field edits; snapshots also catch in-place array edits that do not emit changed.
- Visual appearance and New Resource dialog interaction still require a graphical Godot check; headless global-class registration is verified.

## Circle construction and shared floor — 2026-10-14

Base: merged main `1139a6f`, preserving Godot 4.7 configuration. Tested with Godot 4.5.1 stable Linux x86_64.

- All seven headless suites pass with zero failures and no engine errors: circle_tools, construction, floors, menu_layout, modular_tools, shape_geometry, world.
- Headless editor import and main-scene startup (5 frames) pass. Circle handler is registered through the existing resource interface; menu/editor have no Circle-specific branch.
- Circle tests cover cardinal/diagonal/coarse/negative snapping, approximation area, exact cardinal extents, preview/commit agreement, click no-op, actual render-band triangulation, circle-square merging/erasing, nested holes/islands, repainting, line independence, tangencies, invalid polygons, concave/reversed input, distant centers, cancellation and 24 deterministic mixed edits checked against point-occupancy and contour oracles.
- Independent review found fragmentation/slow contours, far-origin geometry failure and invalid repeated-vertex acceptance. Regression tests reproduced these; replacing fragment subtraction with a scan-band boolean sweep, local calculations and explicit simplicity validation fixes them. Thin render-band triangulation failure was reproduced and fixed with local drawing transforms.
- A 25-circle radius-5 lattice (spacing 3) yields one outline and 214 convex bands. On this host: approximately 174 ms cumulative painting and 4 ms contour extraction, versus several seconds and invalid contours in the initial fragment implementation. Timings are observations, not portable performance guarantees.
- Contour keys quantize to 0.0001 base cells using 64-bit-safe text. The circle's chord-error setting is a target overridden by its segment cap; extreme coordinates retain the engine's float32 precision limit.
- Graphical Inspector/GPU inspection and Godot 4.7 execution remain unverified; headless runtime drawing and class registration are verified.

## Walls, doors and structural regions — 2026-10-15

Implemented on Circle construction commit `ab2ac90` (merged in main as `1a7c641`). Godot 4.7 configuration preserved; validation engine is Godot 4.5.1 stable Linux x86_64.

- Headless editor import, five-frame main-scene startup and all 14 test suites pass with zero failures and no engine errors. Existing seven construction suites remain green.
- New suites cover shared model ownership, sparse wall union/subtraction, atomic invalid edits, stable IDs, door support/state/locking, serialization, snapshot restore, region holes/partitions/lineage, portals, visibility, body clearance, long swept motion, tool integration, inspector mode and event revisions.
- Independent region oracle: 20 deterministic maps of 35 segments compared against a finite cell-flood oracle for connectivity and area. Production topology never allocates cells across the enclosed area. A million-cell-wide rectangle remains four wall records.
- Independent review found incorrect incident regions near wall junctions, rejected restore events reporting revision zero, and cancellation in very long near-tangent capsule sweeps. Each issue was reproduced by a failing regression test, fixed, and verified passing.
- Optional `benchmark_structures.gd` measures validated replacement plus complete topology rebuild for separated rectangular rooms: 100 wall runs / 25 rooms ~9 ms; 500 / 125 ~182 ms; 1,000 / 250 ~676 ms on this host. These are observations, not performance guarantees; intersection and lineage work is quadratic, and dense layouts need future profiling and incremental rebuilds.
- Full-world save/load UI, player undo stack, roofs, agents and semantic ownership remain outside this milestone. Exterior regions can later support meaningful outdoor places without requiring walls.
- Graphical GPU/Inspector validation and Godot 4.7 execution remain unverified. Check wall/door styling, overlapping UI at small window sizes, preview readability across zoom levels, and shift-drag probe appearance when opening the project graphically.

## Circular walls and the shared Door tool — 2026-10-15

Based on the walls milestone merged as main `dd9314c`. Godot 4.5.1 stable Linux x86_64; Godot 4.7 project configuration preserved.

- Fresh headless import, five-frame scene startup, `git diff --check`, and all 16 test suites pass with zero failures and no engine errors. The circular-tool registration assertion failed before implementation.
- Circular Wall and Circle floor share exactly the same boundary sampling. New integration checks exercise scene registration, enclosed area, exterior, actual drawing frames with overlays, coarse-zoom Door previews, stale host rejection, whole-loop erasure, and independence from floors.
- Geometry tests exercise nested and overlapping circles, straight wall partitions, mixed junction incidence, seam/oblique doors, one-cell boundary length, movement and sight, body clearance, locking, occupancy paths, no room rebuild on state toggles, v1/v2 codec compatibility, invalid host references, duplicate circle rejection and snapshot restore.
- Independent review reproduced residual wall collision after opening translated/large curved doors, translated rooms incorrectly becoming their own holes, and portals identifying the same region on both sides. Regression tests failed before fixes. Circular apertures now subtract authoritative boundary-distance intervals, structural arrangement excludes unnecessary door cuts, and portal/boundary incidence comes directly from graph edges and region rings. Hole probes account for float32 coordinate rounding. All original review probes and the regression suite pass afterward.
- Portal checks cover all eight compass positions at origin radius 5, origin radius 100, translated center (10000,10000) radii 20 and 100, and center (100000,100000) radius 5. Clearance regressions also cover center (1000,1000) radius 100 and origin radius 1000. These fixtures establish those cases, not unlimited floating-point precision.
- Circle primitives are compact; geometry work uses their expanded sampled segment counts. Partial arc erasure is deferred; retracing a circle erases the loop and its doors. Graphical GPU/editor appearance and Godot 4.7 execution remain unverified.

## Arc walls for mixed structures — 2026-10-15

Base: main `36624eb` (same tree as local circular-wall delivery `3dbdf84`). Validation engine: Godot 4.5.1 stable Linux x86_64. Godot 4.7 project settings preserved.

- Arc Wall replaces Circular Wall in the current scene and menu. Three-point gestures select center, radius/start and end; Shift selects the opposite sweep; ending at start builds a full loop. Three right-clicks erase only the selected portion. The floor Circle tool remains unchanged.
- All 18 headless test suites pass with zero failures and no engine errors. Fresh editor import, five-frame main-scene startup and whitespace checks pass. The missing arc-command and missing Arc Wall registration tests failed before implementation.
- New geometry checks cover open semicircles, diameter enclosure and area, missing-arc movement, complementary arc union with retained source identity, seam wrapping, partial erasure, whole-aperture door removal, partial door support rejection, undo, schema 3, and fractional straight endpoints.
- Tool checks cover preview/commit geometry, opposite sweeps, Door refusing unbuilt curve portions, frozen staged input, no commit on first release, third-click commit, Escape/tool/focus/inspection cancellation, exact fractional floor-intersection targeting, and a circle merged with a rectangular corridor enclosed by its major arc and straight walls. The omitted circular portion remains traversable inside the combined room.
- Independent review found a conflicting mouse press cancelling a staged gesture and then restarting it in the opposite mode through unhandled input. A real dispatched-event regression reproduced it before the fix and passes afterward. Review reran the original repro and found no remaining Important/Critical issue.
- Straight walls preserve fractional orthogonal endpoints for curve joins; codec versions 1 and 2 remain readable. Old full circles retain full occupancy, while new partial hosts carry normalized boundary-distance ranges. Legacy Circular Wall resources remain for old scenes but are no longer registered by the current world scene.
- Graphical/GPU appearance and Godot 4.7 execution remain unverified. The uploaded screenshot was inspected and informed the mixed-outline regression; headless tests do not establish the visual experience of the three-click gesture. Curves retain bounded polygon sampling, full rebuild costs and floating-point coordinate limits.

## 2026-10-15 — Phase One survival

Godot 4.6 stable, Linux headless: `python3 tests/run_tests.py <godot>` passed
24/24 checks (22 SceneTree suites, editor import, and main-scene startup).
Includes hunger/starvation, finite portions/reservations, fatigue/rest, unseen food
movement, removal during eating, concurrent last-portion use, dead-agent inactivity,
new enclosures/reopened routes, straight/curved barriers, door opening/locks,
modular scene tools, pause, and real pointer snapping at object centers.
No graphical screenshot/playtest was performed in this environment. The project
retains its existing Godot 4.7 feature setting; checks ran on the available 4.6 engine.
Independent review found snapping and inspect-mode issues; both have regression tests.
That review ended early at a usage limit, so it is not a full independent signoff.


## 2026-10-16 — Continuous movement and finite food

Added regression suites for render interpolation and food depletion. Motion tests
verify successive samples between simulation steps, shortest-arc heading interpolation,
corner following, spawn/stationary poses, and no changes to authoritative positions.
Food tests verify a one-serving default, removal after successful consumption, contention
for the last serving, no repeated nutrition from depleted food, and persistent rest.
Both suites failed before implementation and passed afterward. The full runner passed
26/26 checks on Godot 4.6 stable (editor import, 24 SceneTree suites and scene startup).
Graphical playtesting remains manual.
