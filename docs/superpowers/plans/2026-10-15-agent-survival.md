# Agent Survival Implementation Plan

> Execute inline with superpowers:executing-plans; approved conversation defines scope.

**Goal:** Autonomous survival in the existing editable world.
**Architecture:** RefCounted simulation data with Node adapters and Resource definitions.
**Tech Stack:** Godot 4, GDScript, existing SceneTree test scripts.
**Spec:** ../specs/2026-10-15-agent-survival.md

## Constraints and review focus
No combat or social systems. Base-cell simulation coordinates. Preserve all construction
APIs. Review unseen movement, removal mid-action, shared last portions, new barriers,
and trapped agents; these have dedicated scenario assertions.

## Tasks
- [x] 1. Add tests/test_survival.gd covering physiology, provider reservation/consumption,
  belief snapshots and finite nutrition. Observe missing-feature failure, implement
  agents/body_state.gd plus objects definitions/instances/providers/store; rerun.
- [x] 2. Add tests/test_agent_navigation.gd: detour, clearance, locked doors and curved
  barriers. Implement agents/agent_navigation.gd using PhysicalQueries capsule sweeps;
  route(from,to,radius) returns status and points; rerun.
- [x] 3. Add tests/test_agent_simulation.gd: discovery/eating, unseen relocation,
  depleted/removed targets, fatigue/rest, death and topology changes. Implement agent
  data, perception, decisions, controller, simulation; deterministic tick(delta).
- [x] 4. Add placement/scene integration assertions. Add modular construction handlers,
  resource category, rendering, inspector and pause/speed. Run editor import, all
  test_*.gd scripts, and world startup. Document usage and limits; commit review branch.

## Execution record
Initial repository fetched through authorized GitHub connector at main tree
41d10048808393c4aeec74f00acaa69731bd8c35. No AGENTS.md present.
User explicitly requested implementation after approving the scope; proceed inline.


Implementation record:
- Physiology/providers: missing-feature RED followed by survival suite GREEN.
- Navigation: missing-feature RED followed by detours/doors/circles GREEN.
- Agent loop: missing-feature RED followed by resource and fatigue scenarios GREEN.
- Scene integration: absent-view RED followed by tool registration/pause GREEN.
- Review found cell-center snapping and same-tool inspection mode issues; dedicated
  pointer tests reproduced four failures, then passed after fixes.
- Existing modular-menu tests assumed an exact category/tool count. Replaced those
  fixture assumptions with initial inventory plus additions, preserving their assertions.
- Independent review returned actionable findings but ended early due to reviewer
  usage limits. Final validation is automated tests plus author review, not a completed
  independent whole-branch signoff.
