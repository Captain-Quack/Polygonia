# Phase Two History Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement task by task.

**Goal:** Make remembered experiences causally affect autonomous behavior within bounded work and storage.
**Architecture:** A bounded memory model feeds cognition scoring and explanation; physical systems emit observed outcomes. Spatial indexing and route reuse/budgets constrain cost.
**Tech Stack:** Godot 4.5+ GDScript, Godot 4.6 headless validation, Python test runner.
**Spec:** docs/superpowers/specs/2026-10-21-phase-two-history.md

## Global Constraints

- Preserve fixed 0.1-second updates, food conservation and simultaneous combat.
- Memories contain observations, never mutable world references.
- No global social knowledge, hidden-resource discovery or inference of inaccessible food from deferred work.
- Caps: episodes 32, places 64, resources 64, individuals 24, action preferences 16.
- Preserve existing public APIs where tests or editor depend on them.

## Review Focus

- Moving/deleting unseen food must not teach unseen facts.
- Repeated hits/rest pulses must not create independent encounters every tick.
- World edits invalidate routes without resetting autobiographical place memory.
- Budget exhaustion must not increase panic, penalize beliefs or permit predation.
- Invalid snapshots must leave live memory unchanged; shifted clocks preserve ages.

### Task 1: Bounded memory and codec
**Files:** agents/memory/experience_memory.gd, agents/memory/memory_codec.gd, tests/test_history_memory.gd.
**Interfaces:** record(kind, position, now, actor=0, source=0, amount=1, witnessed=false, expected=0); place(position,now), person(id,now), habit(action,position,now); visit(position,now,safe); snapshot(now), restore(data,now).
- [x] Write and run failing tests for coalescing, capacity, place identity, safe recovery, direct/witness weighting and JSON snapshot validation.
- [x] Implement bounded deterministic eviction, decay, event summaries and atomic versioned codec.
- [x] Run focused test; commit with result in progress ledger.

### Task 2: Experience and behavior integration
**Files:** agents/cognition_system.gd; polygon_agent, perception_system, action_controller, option_evaluator, exploration_system, food_social, combat_system, threat_actions; tests/test_history_behavior.gd.
**Interfaces:** AgentCognition.observe(agent,simulation), outcome(agent,option,effects,now), adjust(agent,option,now), route(agent,option,simulation), inspection(agent,now). Agent has memory and next_cognition.
- [x] Write and run failing controlled history-swap and actual event-producer tests.
- [x] Wire actual outcomes, coalesced witnessed attacks, safe familiarity and scarcity learning.
- [x] Apply evidence to resource decisions, exploration, route alternatives and donations; format actual reasons for selected-agent inspection.
- [x] Test unseen events, interrupted meals, counterexperience, history ablation, trust without labels, topology persistence and snapshots.
- [x] Run focused suites and existing survival/food suites; commit.

### Task 3: Bounded perception and navigation work
**Files:** agents/spatial_index.gd; agent_simulation, agent_navigation, perception_system, option_evaluator, threat_actions, food_social, action_controller; tests/test_history_work_budget.gd.
**Interfaces:** spatial.rebuild(items), query(point,radius); navigation.begin_tick(now,expansion_budget=8192), route returns OK/DEFERRED/physical status, route metrics. Observe APIs accept optional candidate arrays.
- [x] Write and run failing spatial-oracle, cache invalidation and deferred-work tests.
- [x] Implement deterministic spatial queries, direct ID lookup, route reuse/cache and a rotating fair decision order with shared A* expansion budget.
- [x] Preserve UNKNOWN semantics at every route caller; cap resource snapshots and discard obsolete retries.
- [x] Run focused and whole suite; compare same benchmark against untouched baseline; commit.

### Task 4: Presentation, documentation and final acceptance
**Files:** world/survival_view.gd; docs/agent-history.md; docs/simulation-performance.md; tests/benchmark_history.gd.
- [x] Cache selected-agent text at a modest cadence and show evidence/reasons without relationship labels.
- [x] Run controlled scenario, long-run bounded-memory and codec tests; run all tests and headless startup.
- [x] Record measured benchmarks, limitations and extension instructions.
- [x] Obtain fresh whole-branch review, fix important defects with regression tests, commit and open a draft PR preserving food-sharing ancestry.
