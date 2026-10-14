# Modular Construction Tools Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make construction buttons and categories Inspector resources, independent of drawing behavior.
**Architecture:** Typed resources describe ordered menu entries; a generic menu emits stable tool IDs. Resource-based handlers own geometry and commit operations; the editor owns input and registers handlers.
**Tech Stack:** Godot 4.5, GDScript.
**Spec:** ../specs/2026-10-14-modular-construction-tools.md

## Global Constraints
Preserve filled squares, grid-aligned lines, styling exports, bottom anchoring and camera cancellation. No additional production tools or room filling.

## Review Focus
- Resource edits and repeated rebuilds must not duplicate callbacks.
- Duplicate or missing IDs must leave valid tools usable.
- Unsupported tools cannot begin construction.
- Multiple category collapse must retain bottom margin.
- Removing the selected tool must cancel a stroke and select an available fallback.

## Task 1: Resources and generic menu
- [x] Add test_modular_tools.gd checking registered resource classes, third tool, second category, invalid IDs, selection, changes and layout.
- [x] Run the test before implementation; expect missing resource failure.
- [x] Add construction_tool_definition.gd, construction_category_definition.gd, default .tres definitions and SVG icons. Replace tool_button.gd and construction_menu.gd with resource-driven controls.
- [x] Verify new tests and existing layout test.

## Task 2: Handler integration
- [x] Extend tests to cover handler registration, unsupported tools and cancellation.
- [x] Add ConstructionToolHandler base Resource with tool_id, commit(data,a,b,step,erase), preview_geometry(a,b,step,cell_size,radius). Add separate line/square handlers and exported defaults.
- [x] Update floor_editor.gd to register handlers and route stable IDs without named buttons or numeric modes. Adapt old tests to public IDs and handler geometry.
- [x] Run all six suites plus headless editor import/startup; document Inspector recipe, review and publish draft PR.

## Progress
Implementation authorized by user; continuing inline on existing refactor/construction-tools branch.

Task 1: complete — Inspector resources, generic menu and regression suite implemented.
Task 2: complete — handler registry and scene resources implemented; six suites, import and startup pass.
Final review: independent reviewer found legacy fallback array refresh; reproduced RED, fixed GREEN, full suite green.
Ruling: retain lightweight configuration snapshots alongside changed signals because in-place Inspector array edits may not emit changed. Cost: linear per-frame traversal of menu definitions.
