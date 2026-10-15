# Polygonia

Open `project.godot` in Godot **4.5 or newer**, open `world/world.tscn`, and press **F6** (current scene) or **F5** (project). Standard Godot is sufficient; no .NET or plugins are required.

## Controls
- Wheel: smooth zoom at the cursor.
- Middle drag, or Space + left drag: pan.
- Home / Return to origin: reset position and zoom.

## Customize in the Inspector
Select **PaperRenderer**: paper color, grain color (including alpha), grain strength, grain scale and seed.
Select **GridRenderer**:
- **Base Cell Size:** persistent world units per logical cell (default 64).
- **Major Step Count:** visible cells between stronger lines (default 5).
- **Level Step Count:** spacing multiplier between zoom levels (default 5).
- Minor/major colors include alpha; Grid Opacity multiplies both.
- Minor/major widths are screen pixels.
- Target Screen Spacing controls when coarser levels become useful.
- Fade Range controls the fraction of each logarithmic zoom interval used to crossfade.
Select **Camera2D**: zoom limits, initial zoom, wheel increment, zoom smoothing (0 = immediate), pan sensitivity, drag options, reset key and home position.

Paper/grid changes preview live in the 2D editor. The editor's own pan/zoom controls apply there; camera navigation applies when playing. To change initial camera framing use Home Position and Initial Zoom on its script. While running, the Remote scene tree allows live tweaks; changes there are temporary.

The renderer nodes should remain at position (0,0), scale (1,1), rotation 0 beneath an untransformed World. The grid uses that common coordinate space. Hide a renderer with its normal Visibility property. Paper is behind grid; future content draws afterward.

## Architecture
The requested tree is preserved with PaperRenderer added first. FloorRenderer and ConstructionPreview provide construction rendering and input. WorldModel owns floors, structures, region topology and physical queries. WallRenderer draws structures; SpatialInspector exposes room and door diagnostics. ObjectContainer and AgentContainer remain extension points. CanvasLayer contains the collapsible ConstructionMenu and view controls.

`viewport_renderer.gd` draws just a viewport-covering polygon, including in editor. Shaders calculate paper texture and line coverage procedurally. No empty-world tiles, sprites, or chunks are allocated while panning.

`GridRenderer.world_to_cell(Vector2)` returns a floored cell coordinate, including for negative positions; `cell_to_world(Vector2i)` returns its top-left corner. Zoom-detail levels are visual only and do not change the construction grid.

The two step counts are independent: try Major Step Count 4 and Level Step Count 3. Levels then show 1, 3, 9, 27 base-cell spacing, with a stronger line every four visible cells. The two complete patterns crossfade; unlike equal step counts, their major lines need not coincide during the transition.

## Scope and limits
This includes graph paper, camera navigation and initial construction tools. Agent simulation, save/load, undo and closed-shape filling are future milestones. Coordinates are practically unbounded for ordinary use, not mathematically infinite. Godot and shader floating-point precision eventually degrades far from the origin. Origin rebasing/chunked content can be added when needed. Zoom has adjustable finite limits to keep navigation usable. Grain fades to its average when too small to resolve, avoiding distant flicker.

## Validation
Run:
```
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_world.gd
```
See `docs/verification.md` for the actual checks performed on this delivery.

Shader reference: https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/canvas_item_shader.html

## Construction tools

The bottom-left **Construction Shapes** category expands upward to reveal Line and Square. Collapsing it preserves the selected tool and its bottom position.

- Line: a thick horizontal or vertical grid-edge stroke with rounded endpoints and joins. Drag direction selects the dominant axis; a click without a drag makes no line.
- Square: a filled rectangle with rounded exterior corners. Connected areas share an exterior outline without internal seams.
- Left-drag paints; right-drag erases the selected kind of geometry.
- Escape, focus loss, or releasing over UI cancels the active stroke.
- Middle drag or Space + left drag pans between strokes.

Snapping follows the dominant visible minor-grid level and is frozen during each drag. Exact base-cell line coordinates are stored separately from filled floor rectangles, providing boundary data for future room recognition. Lines do not auto-fill enclosed spaces yet. Large fills use compact rectangle storage rather than allocating every cell.

Inspector settings are on FloorRenderer (floor/line colors, widths, rounding and pencil texture), ConstructionPreview (preview colors and width), and CanvasLayer/ConstructionMenu (category title, expanded state, colors, button size/gap, icon and border styling).

Run the test scripts under `res://tests`: test_world, test_floors, test_construction, test_shape_geometry, and test_menu_layout. For example:

```sh
godot --headless --path . --script res://tests/test_menu_layout.gd
```

## Git workflow

The initial main branch contains the latest shared project, including the menu positioning fix. Commit source scenes, scripts, shaders and Godot UID files. Generated Godot caches and local credentials are ignored.

Before each change, pull the latest version. After editing locally, commit and push before asking for changes to the same files so both collaborators use the same version.

## Adding construction tools in the Inspector

Open the project once in Godot 4.5+ so it imports scripts and registers the resource classes. `ConstructionToolDefinition` and `ConstructionCategoryDefinition` then appear in **New Resource** (and the typed array element dropdowns).

1. Select `World/CanvasLayer/ConstructionMenu`. Expand **Categories**, then the existing category resource and its **Tools** array. Line and Square are editable `.tres` resources here, not named buttons in code.
2. Add a Tools element and choose **New ConstructionToolDefinition**. Set a unique **Tool Id** (for example `door`), **Display Name**, **Tooltip**, and optional **Icon**. With no icon, the button shows its label. Save the resource if you want to reuse it.
3. For another submenu, add **New ConstructionCategoryDefinition** to Categories. Set its unique **Category Id**, **Title**, **Default Expanded**, and ordered Tools. **Columns** on the menu controls wrapping. Selection is shared across categories.
4. To give the new tool behavior, extend `ConstructionToolHandler` in a script, set `tool_id` to the same ID, and override `commit(data, a, b, step, erase)` and `preview_geometry(a, b, step, cell_size, radius)`. The Line and Square handler scripts under `floors/tools/` are working examples. Preview returns a dictionary with `paths` and `fills` arrays of `PackedVector2Array` in world pixels, plus `closed` and optional `use_line_width` booleans.
5. Create a Resource using your handler script and add it to **Tool Handlers** on `World/ConstructionPreview`. Alternatively, call `register_handler(handler)` at runtime. No menu or editor changes are needed. Unregistered tools remain visible but disabled at runtime with an explanatory tooltip; they remain visible in the editor for layout.

Empty or duplicate IDs are skipped with configuration warnings on the menu. The first valid occurrence wins. Removing the active definition/handler selects the first available tool and cancels the stroke; with none available construction stops. A missing Categories array uses the default category and legacy Category Title/Expanded settings for older scenes. Explicit resources take precedence over those legacy settings.

Menu resources update in the editor when their fields/arrays change. The existing `icon_width` setting now scales texture icons relative to its default 3.5; edit the SVG asset to change stroke thickness. Line widths in the world are still controlled by FloorRenderer.

Run `test_modular_tools.gd` in addition to the five existing suites. It exercises a test-only third handler, multiple categories, live edits, unsupported/invalid IDs, selection and repeated collapse/rebuild cycles.

## Circle construction

Circle is a filled-floor tool in Construction Shapes. Click a grid intersection for the center and drag to set radius. Both center and radius snap to the active grid; diagonal drags use Euclidean distance rounded to a grid multiple. The snap step stays frozen during the drag. The preview shows the center, four cardinal extents, a guide to the actual snapped circumference, and radius/diameter in base cells. A click without dragging does nothing.

Circle and Square edit the same floor. Painting overlapping shapes merges their fill and exterior outline; either tool can erase the other's floor, create holes, or split islands. Repainting fills holes without darkening overlap. Point tangencies retain separate contours. Line strokes stay independent; floor erasing leaves them intact. Escape, tool switching, focus loss, and releasing over UI cancel a drag.

Inspector controls:
- `ConstructionPreview → Preview Guides`: guide visibility, color, width, marker radius and text size. Erase guides use the erase-ink color.
- Its Circle handler resource in **Tool Handlers**: **Target Chord Error Cells** and **Max Segments**. Circle approximations have at least 64 vertices and exact cardinal points. Vertex count depends on radius/accuracy, never zoom. The segment cap takes precedence over target accuracy; very large circles may show facets when magnified.

Shared floor APIs are `apply_rect(rect, erase)`, `apply_polygon(points, erase)`, `contains_point(point)` and `boundary_loops()`, all in base-cell coordinates. Rectangle-only worlds retain compact integer rectangles. A valid polygon edit promotes the floor to a disjoint polygon scan-band backend, after which `regions` is empty; consume the query/contour APIs instead. `contains(cell)` tests the cell center after promotion. Simple concave polygons are supported; self-intersections and nonadjacent touching/repeated vertices are rejected without changing floor state. A future filled tool can generate a simple polygon and use the same backend without special merging logic.

Scan-band Boolean edits split at boundary intersections, union/subtract intervals, and produce non-overlapping trapezoids. Horizontal seams cancel into outer/hole contours; translucent fill is drawn once. Topology keys quantize to 0.0001 base cells and avoid 32-bit scaling overflow. Calculations and fill-band triangulation use local origins; the engine's floating-point coordinate precision still limits detail extremely far from the origin.

Run `test_circle_tools.gd` alongside the six existing suites. It verifies snapping, preview/commit agreement, cardinal extents, square/circle interoperability, nested holes and islands, point tangencies, mixed-edit occupancy, invalid input, distant circles, renderer geometry, and 25 overlapping circles. Structural room recognition and passage queries are available through WorldModel; agent decision-making remains future work.

## Walls, doors and structural regions

The **Structures** menu contains Wall, Arc Wall and Door. Wall drags follow the dominant axis and visible grid; right-drag erases. Floor Line remains decorative and does not divide rooms. Door targets an existing wall and always occupies one base-cell interval, even at coarse zoom. Right-click a door to remove it, restoring solid wall. Invalid previews show a reason and cannot commit. Erasing a wall must remove an entire supported door or leave it fully supported.

**Inspect mode** disables construction. Click a room or door; the inspector reports region IDs, area, portals, door state and validation feedback. Open/Close/Lock/Unlock act on the selected door. **Region overlay** displays bounded areas and portals. Shift-drag while inspecting probes movement with a 0.2-cell-radius body and a sight line. Escape or selecting a construction tool leaves Inspect mode.

Rooms represent structural enclosure: an open door connects two rooms without merging their identities. Exterior is region `0`; roof coverage is explicitly **Unknown**. An enclosed courtyard therefore is not automatically weatherproof. Social meanings such as home, meeting place or garden can later reference arbitrary areas, including outdoor space, independently of structural rooms.

Agent-facing interfaces are `WorldModel.regions.locate(point)`, `get_regions()`, `get_portals()` and `WorldModel.physical.sweep(start, end, radius)`, `visibility_hits(start, end)` and `crossing_option(door_id, profile)`. Positions are in base cells. Door profiles provide `radius` and `can_open_doors`. Commands validate against current world state; consumers can subscribe to `structure_changed` and `world_replaced`. Geometry, barriers and traversal permissions have separate revisions. Install an `occupancy_query` callback before introducing bodies so closing doors can reject occupied apertures.

Storage uses sparse orthogonal segments, with fractional endpoints where needed to join curves, within ±1,000,000 base cells. Region work scales with geometry, not enclosed cell count. Full topology rebuilds currently use quadratic comparisons; large dense structures can cause editing pauses. Physical walls and closed doors have a 0.05-cell collision radius. Body clearance and sight use the same barrier representation. Rendering still inherits Godot's floating-point precision limitations far from the origin.

`StructureCodec` provides validated versioned serialization; command snapshots support internal restore/redo. A player save/load UI, global undo stack, roofs, navigation planner and agent behaviors are not included. Existing floor-handler `commit`/`preview_geometry` APIs remain supported; new tools can override `propose_edit(context, gesture)` for validated commands and precise previews.

Run all `tests/test_*.gd` scripts headlessly, and optionally `tests/benchmark_structures.gd`. See `docs/verification.md` for measured results and graphical validation limits.

## Arc walls and curved doors

**Structures → Arc Wall** replaces Circular Wall and supports full circles as well as partial curves. Use three clicks:

1. Click the center on the grid.
2. Click the radius/start point. Radius and center use the same frozen grid spacing as the floor Circle tool.
3. Move around the center and click the arc's end. Hold **Shift** for the opposite sweep. Select the start again for a full circle.

The preview shows the exact wall path, center, radius guides, endpoints and sweep. Nearby floor-outline vertices and existing straight-wall intersections provide join targets, including fractional circle/rectangle intersections. Use Wall to continue straight from an arc endpoint; it snaps to structural endpoints and floor vertices. Endpoints can therefore meet the outline of a Circle floor merged with rectangles without creating the unwanted remainder of a circular wall.

For erasing, use **three right-clicks** in the same center/start/end sequence. Only that arc is removed. Painting overlapping or complementary arcs combines them. Escape, changing tools, inspecting, focus loss, a conflicting world mouse press, or interacting with UI cancels the staged gesture. Existing floor tools retain drag painting/erasing.

Use the existing **Door** tool on either straight or curved walls. Curved doors follow one base cell of boundary length, including across sample vertices and the full-circle seam. They must fit entirely within a built arc; the tool cannot target missing portions. Erasing an entire aperture removes its door; erasing only part of its support rejects the edit. Door placement snaps locally at quarter-cell distances along the boundary, independently of visible-grid zoom. Open, close, lock, occupancy checks, inspection and right-click removal use the same controls.

Circle hosts store center, radius, sample count, stable ID and normalized occupied boundary-distance intervals compactly. `get_circles()` exposes these hosts; a missing `ranges` field means a full loop. `circle_ranges()` and `circle_paths()` expose occupied portions; `get_wall_segments()` expands only built wall centerlines. `get_doors()` adds a derived `path` to curved doors; `StructureData.door_path(door)` returns the path for either kind. Occupancy callbacks receive `path` as well as `a`, `b`, `radius` and `id`; check every path segment for curved doors.

Codec version 3 represents partial arcs and fractional orthogonal endpoints. Versions 1 and 2 remain readable, and old circles load as full loops. Legacy Circular Wall resources remain available for old scenes, but the current scene registers Arc Wall in their place. New construction handlers can override `control_point_count()` and `instructions()` for staged point input without adding tool-name branches to the editor.

Curves use the floor tool's bounded polygon approximation. Rendering, movement, visibility and room recognition consume the same sampled shape. Work depends on expanded segment count. Godot float precision limits detail far from the origin; origin rebasing remains future work. Arc centers and radii remain grid based; this addition does not introduce freeform splines or arbitrary diagonal straight-wall drawing.

## Phase One: autonomous Polygons

The **Life** tools place Polygons, finite food sources and resting places. Polygons
perceive and remember resources, navigate walls and doors, eat, rest and suffer
starvation. Use **Inspect Polygon** and the pause/speed controls to observe them.
See [the survival guide](docs/agent-survival.md) for usage, extension points and limits.
