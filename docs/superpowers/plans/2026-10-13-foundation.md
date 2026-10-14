# Graph Paper Implementation Plan

> Use superpowers:executing-plans to implement this plan inline.

**Goal:** Deliver an editable Godot graph-paper world.
**Architecture:** Viewport-covering Node2D renderers draw world-space procedural shaders; Camera2D owns navigation. World tree preserves future content layers.
**Tech Stack:** Godot 4.5+, GDScript, canvas_item shaders, Compatibility renderer.
**Spec:** ../specs/2026-10-13-foundation-design.md

## Global Constraints
No external add-ons; settings exported; tool preview; fixed logical cells; no empty tile allocations.

## Review Focus
- Zoom while cursor is off center must preserve its world point.
- Independent step counts must remain independent.
- Negative world coordinates use floor cell mapping.
- Reversed zoom limits cannot produce zero/negative zoom.
- UI interactions and focus loss must not cause unintended panning.

## Task 1: Renderers and scene
Create world/viewport_renderer.gd, paper_renderer.gd, grid_renderer.gd; shaders/paper.gdshader and grid.gdshader; world/world.tscn; project.godot.
Interfaces: GridRenderer.world_to_cell(Vector2)->Vector2i; cell_to_world(Vector2i)->Vector2. Renderers expose Inspector properties and synchronize shader uniforms in tool/runtime mode.
Write tests for negative cell mapping and independent step counts before implementation. Import project and run smoke suite after implementation.

## Task 2: Camera and controls
Create world/world_camera.gd. Interface: zoom_about(Vector2 screen_position, float new_zoom), reset_view(). Export navigation settings. Connect reset button in scene. Tests check actual canvas transforms before/after anchored zoom, bounds and reset. Run headless suite and graphical rendering smoke check.

## Task 3: Delivery
Document controls and Inspector fields in README.md, record verification, package clean source ZIP without .godot cache. Save deliverable.
