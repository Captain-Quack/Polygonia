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
The requested tree is preserved with PaperRenderer added first. FloorRenderer and ConstructionPreview provide construction rendering and input. WallRenderer, ObjectContainer, AgentContainer, and Inspector remain extension points. CanvasLayer contains the collapsible ConstructionMenu and view controls.

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
