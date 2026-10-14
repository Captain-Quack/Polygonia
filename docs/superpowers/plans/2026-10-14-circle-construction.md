# Circle Construction Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline.

**Goal:** Add grid-snapped filled circles interoperating with existing squares.
**Architecture:** Lazy polygon floor backend preserves rectangle efficiency; handler owns circle math; generic editor renders optional guides.
**Tech Stack:** Godot 4.5-compatible GDScript, current project's Godot 4.7 settings preserved.
**Spec:** ../specs/2026-10-14-circle-construction-design.md

## Global Constraints
Base-cell storage, frozen active snap spacing, independent Line strokes, no per-cell allocation, preview/commit agreement.

## Review Focus
Tangencies and corner-touch contacts; nested holes; invalid input; fragmentation; approximation stability across zoom.

## Task 1: Shared floor geometry
- [x] Add failing polygon/circle test suite.
- [x] Implement polygon_floor.gd: apply_polygon, contains_point, boundary_loops; disjoint convex scan bands and shared horizontal edge cancellation.
- [x] Integrate lazy promotion into floor_data.gd and preserve rectangle tests.
- [x] Run new geometry suite plus all regressions.

## Task 2: Circle tool and preview
- [x] Add handler radius/preview/integration assertions.
- [x] Implement circle_handler.gd/resources/icon; register through existing scene resources.
- [x] Add generic optional preview guides and labels; preserve shallow curve vertices in rounded_loop.
- [x] Verify all suites, import and startup; independent review; fix reproduced defects; document and publish PR.

## Progress
User explicitly requested full implementation and design improvements; proceed inline without another approval round.

Task 1 complete: scan-band boolean backend and promotion, point-oracle and nested-hole regressions pass.
Task 2 complete: resource-driven Circle, generic guides, seven suites pass; independent review fixes reproduced and verified.
Ruling: use scan-band boolean operations rather than convex half-plane fragmentation — overlapping-circle stress exposed excessive fragments and contour roundoff. Cost: work scales with boundary intersections/heights, not cells; more complex maps will still need profiling.
Ruling: chord accuracy is a target capped by max_segments — preserves bounded construction work; very large circles may show facets at high zoom.
