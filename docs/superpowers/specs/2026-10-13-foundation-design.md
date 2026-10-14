# Polygonia graph-paper foundation

Approved conversational design, including the user's instruction to begin implementation.
Godot 4.5+, GDScript, Compatibility renderer. A standalone project with the proposed World scene hierarchy plus PaperRenderer. No external assets or add-ons.

Paper: warm ivory, subtle stationary procedural grain, independently adjustable color, grain color/strength/scale. Grid: world-anchored antialiased lines; base cell size 64; major lines every 5 visible cells; detail spacing multiplier 5. These two step counts are independent integers >=2. Zoom never changes logical cell size. Adjacent grid levels crossfade continuously. Minimum displayed level is the base grid: zooming in never implies smaller construction cells.

All appearance and navigation choices are exported with Inspector hints. Renderers are @tool and display in the 2D editor using its canvas transform. Render only the visible viewport; no tile allocation. Floating point precision remains finite; origin rebasing is out of scope.

Mouse wheel zooms around cursor; middle drag or Space+left drag pans. Zoom smoothing keeps cursor anchor fixed. Reset returns to origin and initial zoom. GUI input must not move camera. Camera stops dragging on focus loss. Zoom limits are sanitized if reversed.

Separate renderer scripts, shaders, camera script. Renderer draws a viewport-sized polygon transformed to local coordinates. Shader uses interpolated local coordinates and screen derivatives. Existing floor/wall/objects/agents/preview containers are empty placeholders. Minimal controls are ordinary editable scene nodes.

Validate scene import, headless scene execution, cursor anchor invariance, negative-coordinate cell mapping, clamped zoom, independent grid settings, and shader rendering. Manual visual review covers warm appearance, grain aliasing and level transitions.
