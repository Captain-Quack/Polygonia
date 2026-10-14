# Modular construction tools

## Purpose

Make adding construction buttons and categories straightforward in Godot's Inspector. Keep presentation independent from tool behavior so future ideas do not require editing menu creation, icon drawing, selection, and input dispatch in several places.

The existing Line and Square tools retain their behavior, appearance, grid snapping, erasing, cancellation, and camera interaction. Squares stay filled. Line boundaries remain separate from floor occupancy. Closed-shape filling, room recognition, save/load, undo, and new production tools are outside this refactor.

## Definitions and menu

- A `ConstructionToolDefinition` Resource stores a stable `StringName` ID, display label, tooltip, and `Texture2D` icon. Line and Square use supplied SVG icons. Unknown icons may fall back to the display label; adding an icon requires no menu code.
- A `ConstructionCategoryDefinition` Resource stores a stable category ID, title, default expanded state, and an ordered array of tool definitions.
- The top-level construction menu exports an array of category definitions. It creates one reusable collapsible category view per definition and keeps exclusive selection across all categories.
- A generic tool button renders the supplied definition using shared styling. It has no Line/Square enum or knowledge of construction geometry.
- The menu exposes `tool_selected(tool_id)`, `select_tool(tool_id)`, and lookup by stable ID. Editor input connects once to the menu signal rather than to named buttons.
- Category views handle expansion and their own content layout. The overall bottom anchor remains fixed when any category opens, closes, or changes content. Tool grids have an Inspector-editable column count so additional buttons wrap rather than extending indefinitely across the screen.

IDs must be nonempty and unique. Invalid or duplicate definitions produce a clear configuration warning and are skipped without preventing valid tools from loading. Selection stays active when its category is collapsed. If the selected definition disappears, selection falls back to the first available registered tool; if none remain, construction is inactive.

## Behavior handlers

A small construction-tool base class defines preview geometry and commit operations using snapped base-cell endpoints, stroke spacing, and paint/erase mode. Line and Square are separate handlers implementing that contract. No engine-wide action framework is introduced.

The construction editor owns stroke input, snapping, camera suspension, cancellation, and FloorData. It registers handlers by stable tool ID and delegates previews and commits to the selected handler. It no longer uses numeric tool comparisons to distinguish Line and Square.

Registration is explicit and simple: add one handler registration for a new implemented tool. The menu can display arbitrary definitions independently, but unregistered tools are disabled during play and show an explanatory tooltip; they never silently invoke another tool. Editor previews still show configurable definitions without requiring game initialization.

## Styling and migration

Keep existing exported menu appearance properties as the shared styling controls to preserve serialized Inspector overrides. The category_title and expanded properties remain compatibility inputs for an existing scene that has no explicit category definitions. That scene receives the default Construction Shapes category containing Line and Square, so pulling the refactor does not require reconstructing the scene.

Explicit category definitions control their own titles and initial expanded state. Definitions and icons are editable/reusable assets. Resource changes refresh the editor preview through change notifications; generated controls are cleaned up during rebuilds. Repeated rebuilds do not duplicate controls or signal connections.

The fixed bottom-position behavior is retained. Changes to button size, category content, and expansion preserve the bottom margin. Colors, button dimensions, icon width where applicable, border width, corner radius, spacing, and wrapping columns remain Inspector-editable.

## Adding a tool

1. Create a tool-definition Resource and choose a unique ID, label, tooltip, and icon.
2. Add it to a category's ordered tool list in the Inspector.
3. Implement and register its handler to enable its construction behavior during play.

No menu or button rendering changes are required. Add a category by creating another category-definition Resource and adding it to the menu's exported list.

## Validation and acceptance

- Preserve the existing world, floor, geometry, and menu-position regression suites, updating assertions to use stable IDs and the public menu API.
- Add a third test tool and a second category through definitions without modifying the menu implementation. Verify creation, ordering, icon/tooltip presentation, exclusive selection across categories, and one selection event per click.
- Verify an unregistered tool is disabled, and duplicate/empty IDs do not break valid buttons.
- Verify selecting a tool cancels an active stroke; collapsing categories preserves the current tool.
- Verify repeated category toggles, definition rebuilds, button-size changes, wrapping, and viewport resizing preserve the bottom margin.
- Verify both handlers produce the same stored geometry and preview shapes as before, including reversed drags, dominant-axis lines, coarse snapping, erasing, and holes.
- Godot headless editor import and populated scene startup must pass. Graphical appearance still requires a local editor check unless graphical verification becomes available.

Deliver the refactor on a GitHub branch/PR with a concise README recipe for adding tools. Do not merge into main until the user chooses to adopt it.
