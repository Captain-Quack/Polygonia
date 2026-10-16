# Emergency Behavior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Polygons explainable survival decisions, deprivation-dependent impairment, and conditional extreme predation with defensive responses.

**Architecture:** Keep bodily state, assessment, motivation, and execution separate. Reuse observed resource beliefs, navigation, reservations, and finite providers. Resolve combat from a common snapshot and represent dead bodies as ordinary finite resources.

**Tech Stack:** Godot 4 GDScript, Resource configurations, existing SceneTree tests and Python test runner. No additional product dependencies.

**Spec:** `docs/superpowers/specs/2026-10-16-emergency-behavior-design.md`

## Global Constraints

- The player changes the world, not agent commands.
- Urgency and capability are separate.
- Survival is not guaranteed when relief is genuinely unavailable or too late.
- All thresholds, equations, trait distributions, recovery times, attack rules, and simulated time scales are authored simulation choices, not clinical predictions.
- Keep current hunger, fatigue, starvation damage, and completed-meal semantics.
- Health does not regenerate in this increment.
- Ordinary food reservation ties remain ordered.
- Preserve the local rest improvements and verify them with the new emergency cases before delivery.
- No external upload or merge is performed by this plan.

## Review Focus

1. Invalid configuration and zero rates: assessment must never emit NaN or accidentally turn infinite survival time into imminent death (Task 1).
2. A detour is longer than straight-line distance: feeding estimates must use validated route length without exhausting navigation budgets (Task 2).
3. A target disappears or changes behind a wall: pursuit must not read its live position or remain reserved indefinitely (Task 4).
4. Simultaneous death, deletion, and feeding: exactly one corpse and one finite yield per death, no effects from cancelled use (Task 5).
5. A large frame delta or changed simulation speed: fixed-step rendering and decision stability must remain intact (Task 6).

## Execution and verification conventions

Implement inline in the existing task branch after plan review; preserve the approved rest changes and existing commits. Confirm the working tree is clean and inspect any applicable AGENTS.md first. Do not reset unrelated work.

Use the existing Godot binary if present, otherwise acquire an official compatible binary. Commands below use `$GODOT_BIN` set to that executable; this is a task-specific variable. Record the actual engine version. Project configuration currently declares 4.7; prior verification used 4.6. Do not silently change the version requirement.

Each task follows red/green: write its tests, run them and confirm the intended failure, implement, rerun focused tests, then commit. When adding a globally named script, run `"$GODOT_BIN" --headless --path . --editor --quit` before its tests. Run a focused test with `"$GODOT_BIN" --headless --path . --script tests/<file>.gd`; require exit zero, zero reported failures, and no engine script errors. The full suite is `python3 tests/run_tests.py "$GODOT_BIN"`.

## Task 1: Physiology, profile, and emergency assessment

**Files:** Create `agents/emergency_profile.gd`, `agents/emergency_assessment.gd`, `agents/personality.gd`, `tests/test_emergency_state.gd`; modify `agents/body_state.gd`, `agents/polygon_agent.gd`, `agents/agent_simulation.gd`.

**Interfaces:**
- `EmergencyProfile extends Resource`: exported rates, boundaries, combat settings and `validate() -> PackedStringArray`. Reject nonfinite values, negative rates, inverted nourishment boundaries, and invalid durations. Simulation uses validated copies so mutable shared Resources cannot change policy halfway through a tick.
- `PolygonBody.deprivation: float`, `tick_deprivation(delta: float, profile: EmergencyProfile) -> void`.
- `EmergencyAssessment.evaluate(body: PolygonBody, profile: EmergencyProfile) -> Dictionary`: `urgency`, `impairment`, `mobility`, `fatal_after`, `harm_rate`.
- `EmergencyAssessment.damage_over(body: PolygonBody, seconds: float) -> float`: exact integration of current nourishment drain and starvation curve; `fatal_after` inverts this piecewise integral.
- `AgentPersonality.from_seed(simulation_seed: int, agent_id: int) -> AgentPersonality`: stable caution, persistence, aggression in [0,1]. Agent owns personality, assessment, and `effective_speed() -> float`.

- [ ] Write tests asserting zero nourishment/full health gives `fatal_after == 50` under existing damage rate 0.02, health 0.12 gives 6 seconds, zero damage gives infinity, and zero hunger drain with subthreshold nourishment still causes the correct finite damage.
- [ ] Add integration assertions: at nourishment zero, 60 seconds gives deprivation 0.5; nourishment 0.40 for 90 seconds restores it to zero. A meal cannot reset deprivation directly. Compare small and large integration steps within declared numerical tolerance; test invalid profiles and dead bodies.
- [ ] Run the test and confirm missing emergency behavior fails.
- [ ] Implement the interfaces. Defaults: deprivation threshold 0.25, recovery threshold 0.40, buildup 120 seconds, recovery 180 seconds, maximum mobility penalty 0.25. Use continuous severity, not abrupt named emergency states. Integrate threshold crossings rather than assuming a whole long step is spent at its final nourishment.
- [ ] Verify tests and stable trait assignment across seeds and agent creation; commit this independently testable state model.

## Task 2: Survival choices and interruption

**Files:** Create `agents/motivation_system.gd`, `agents/option_evaluator.gd`, `tests/test_emergency_decisions.gd`; modify `agents/decision_system.gd`, `agents/action_controller.gd`, `agents/agent_simulation.gd`, `tests/test_rest_spots.gd`.

**Interfaces:**
- `AgentMotivation.weights(agent: PolygonAgent) -> Dictionary`: continuous priorities and reason strings.
- `AgentOptionEvaluator.evaluate(agent: PolygonAgent, options: Array, simulation: AgentSimulation) -> Array`: enrich candidates with route status, route points, estimated relief time, predicted health, urgency, and reason.
- Extend `AgentDecision.candidates(agent, now, revision, simulation = null) -> Array` compatibly; production passes simulation, old callers retain ordinary candidate generation.
- `AgentActionController.reconsider(agent, options, now, urgent: bool = false) -> void`: bypass ordinary hysteresis on imminent harm or direct threat, preserve same-target progress.

- [ ] Write the known regression: nourishment 0, fatigue 1, health 0.12, deprivation 0, food at (3,0), rest at origin. Assert immediate food pursuit, successful meal, survival, and no rest reservation leak after eight simulated seconds.
- [ ] Add health-sensitive choice, severely deprived searching with no known food, late fatal meal with unchanged stock, almost-complete meal preservation, blocked/reopened paths, detour timing, and moved resource tests. Verify the existing full rest-session cases remain valid.
- [ ] Run and observe failures for the new survival decisions.
- [ ] Generate ordinary candidates first; enrich the best candidates under a maximum of eight route validations per decision. Carry evaluated routes into execution to avoid duplicate work. Invalidate on observed destination or traversal revision change and recompute timing from current speed and position. Unevaluated candidates remain explicitly uncertain; rotate validation across pending candidates so the cap cannot permanently hide a feasible option.
- [ ] Compute relief time from route length minus contact allowance plus remaining interaction time; predict health with Task 1's integral. Prioritize timely nourishment when the delay imposed by current rest would make it fatal. Outside danger retain normal utility and hysteresis. Increase exploration under severe deprivation when no known food is viable.
- [ ] Check each fixed tick for newly imminent harm without doing an unlimited navigation search. Interrupt and release providers by the next tick; retain the existing half-second normal decision schedule.
- [ ] Verify focused tests, run the existing rest/navigation/survival tests, and commit.

## Task 3: Bounded impairment and explainable variation

**Files:** Modify `agents/motivation_system.gd`, `agents/option_evaluator.gd`, `agents/action_controller.gd`, `agents/polygon_agent.gd`; create `tests/test_emergency_variation.gd`.

**Interfaces:** Agent stores `decision_reason: String`; options carry reason strings. Familiarity uses observed resource history, not live object references. Candidate consideration limit ranges from eight to two as impairment rises.

- [ ] Write paired-agent tests with equal hunger but different deprivation: mobility and ordinary alternative consideration differ, direct threat processing does not slow, and one meal leaves residual impairment.
- [ ] Test seeded replay, known failed targets excluded despite persistence, and eventual consideration of an unfamiliar feasible target. Removing the impairment modifier or failed-target exclusion must fail these assertions.
- [ ] Run to confirm the intended failures.
- [ ] Apply bounded familiarity preference modulated by persistence; apply caution to risky options. Keep the current target eligible for comparison even when limiting alternatives, and never override negative observations or retry cooldowns. Seed any tie-breaking once through the simulation; do not introduce frame-based randomness.
- [ ] Verify no oscillating intentions under unchanged inputs; verify gradual recovery and smooth movement; commit.

## Task 4: Perceived threats, pursuit, escape, and simultaneous combat

**Files:** Create `agents/combat_system.gd`, `agents/threat_actions.gd`, `tests/test_agent_combat.gd`; modify `agents/perception_system.gd`, `agents/polygon_agent.gd`, `agents/decision_system.gd`, `agents/agent_simulation.gd`, `agents/action_controller.gd`.

**Interfaces:**
- `AgentPerception.observe_agents(agent, agents: Array[PolygonAgent], model: WorldModel, now: float) -> void` stores position, time, visible condition band, and hostile action snapshots by ID.
- `AgentThreatActions.candidates(agent, simulation) -> Array` and `tick(agent, simulation, delta: float) -> void` produce/execute pursue, flee, defend intentions using existing movement/navigation helpers.
- `AgentCombatSystem.queue_strike(actor_id: int, target_id: int, feeding: bool) -> void`, `resolve(simulation) -> Array` return resolved events. Cooldowns belong to actors and survive intention changes.
- Agent has `agent_beliefs`, threat timestamps, and bounded lost-target search state; simulation supplies `get_agent(id: int) -> PolygonAgent` for execution validation only.

- [ ] Write tests that ordinary hunger cannot attack; extreme eligibility can allow an aggressive fixture to attack while zero aggression rejects predation; timely ordinary food suppresses attacks.
- [ ] Write tests for contact/cooldown/LOS validation, no remote target tracking, target removal, immediate rest interruption and reservation release, escape through available space, trapped defense, and mutually lethal simultaneous attacks with reversed list order.
- [ ] Observe failures before implementing combat.
- [ ] Gate predation on enabled profile, deprivation at least 0.65, nourishment below 0.10, ongoing starvation harm, and absence of timely ordinary food. Evaluate expected injury cost using visible condition bands and traits; never access hidden exact target health during choice.
- [ ] Use contact distance actor radius + target radius + 0.10, strike interval 1 second, base damage 0.10 reduced by attacker impairment. Queued strikes validate against the same post-movement snapshot; aggregate damage before cancelling newly dead agents.
- [ ] Order simulation phases as physiology/death cleanup, perception/assessment, decisions, actions/movement, combat resolution, death/resource cleanup. Direct attack notifications force the next tick's threat reconsideration.
- [ ] Escape evaluates a bounded set of collision-valid destinations with increasing separation. Defense is available when escape cannot be found. Pursuit uses only observed positions, followed by a bounded local search. Loss of sight does not permit querying live coordinates. Keep exploration/escape routes under the existing bounded navigation service.
- [ ] Verify all focused scenarios and the existing motion/navigation suite; commit.

## Task 5: Finite corpses and consumption lifecycle

**Files:** Create `objects/definitions/corpse.tres`, `agents/death_system.gd`, `tests/test_corpse_resources.gd`; modify `agents/agent_simulation.gd`, `agents/decision_system.gd`, `agents/action_controller.gd`, `agents/polygon_agent.gd`, `objects/interaction_definition.gd`, `objects/interaction_provider.gd`.

**Interfaces:**
- `AgentDeathSystem.materialize(agent, simulation) -> void` is idempotent via an agent death-handled flag and corpse ID.
- Add `InteractionDefinition.requirement: StringName` default empty and include it in provider observations. Corpse uses `extreme_feeding`; standard food remains unrestricted. Admission policy is shared by choice and execution.
- Corpse provider stock 1, duration 2 seconds, nourishment 0.45, remove when depleted. Dead agent identity can remain for diagnostics but stops rendering and occupying geometry after conversion.

- [ ] Write tests for exactly one corpse after repeated ticks, starvation and combat deaths, no corpse on editor deletion of a living agent, simultaneous killers, single-consumer reservation, cancellation on move/removal, and complete depletion/removal.
- [ ] Verify noneligible agents cannot select or begin corpse feeding; defenders do not acquire predatory feeding intent simply by killing an attacker. Eligible survivors can discover the remaining resource normally.
- [ ] Observe failures, then implement materialization and capability requirements. Grant nutrition only on completed consumption, never on hits or kills. A reservation must release immediately on actor death or removal. Clone per-corpse mutable configuration if edible yield differs; never mutate a shared definition.
- [ ] Recheck eligibility before beginning consumption; an already admitted meal may finish unless interrupted, so slight relief or changed alternatives cannot strand accounting. On death conversion use the final world position and transfer visual presence once. Exclude converted agents from occupancy checks.
- [ ] Verify finite-food/rest tests and new corpse tests; commit.

## Task 6: Inspection, integrated verification, and delivery

**Files:** Modify `world/survival_view.gd`, `agents/agent_renderer.gd`, `docs/agent-survival.md`, `docs/verification.md`; create `tests/test_emergency_integration.gd`.

**Interfaces:** Inspection reads assessment and `decision_reason`; rendering remains independent of decision policy. Corpse visuals use its object definition and never duplicate a converted agent.

- [ ] Write integration tests for pause/fixed-step behavior where accessible, seeded replay, finite numbers after long simulation, removal of an attacking/feeding agent, and scenarios spanning perception, navigation, rest, threats, and consumption. Check recorded event reasons and health/resource outcomes.
- [ ] Implement compact inspection values for urgency, deprivation, impairment, target and reason. Use readable action labels; render pursuit, fleeing, rest, food and corpse states distinctly while preserving rounded triangles and interpolation.
- [ ] Run focused integration tests, then `python3 tests/run_tests.py "$GODOT_BIN"`. Require all checks passing and report every unresolved failure by name.
- [ ] Run an interactive scene check if the environment supports it: normal rest, food relocation, blocked doors, urgent feeding, pursuit, flight, death and corpse disappearance. If unavailable, explicitly record that only headless verification was completed; do not claim visual playtesting.
- [ ] Review the whole diff against the spec, especially no omniscient pursuit, no duplicate nutrition, no premature rest interruption, and no changes to unrelated construction systems. Update verification docs with commands, engine version, numerical tuning, and remaining limitations. Mark plan steps according to actual results.
- [ ] Commit the integrated result. Prepare a concrete summary and draft PR content including pending rest fixes; external upload follows the session's authorization and automatic approval-review constraints. Never merge without explicit instruction.

## Plan self-review

All spec areas map to Tasks 1–6. Recovery and health are deliberately distinct; health regeneration remains excluded. Route budgets include eventual consideration rather than silently suppressing distant options. Emergency admission is checked during execution as well as choice. Combat order independence applies to simultaneous strikes, not ordinary food allocation. Corpse creation is idempotent and replaces dead-agent occupancy. All five review-focus conditions have owning test steps. The plan introduces no external dependencies or unrelated world-building features.


## Execution record

Implemented in local commits c444dba through 8f8b57e, followed by a consolidated
review-fix commit. Tasks 1–6 have executable coverage in the emergency state, decisions,
variation, combat, corpse, integration and review-regression suites. The existing rest,
food, movement, navigation and scene suites also remain required gates. Numerical
integration replaces endpoint-only starvation damage to match deadline estimates.

Rulings: conservative food/search priority replaces optional optimal rest-break
planning; busy-provider failures use a 0.5-second retry instead of the route-failure
8 seconds; progress tracking used a direct local ledger because skill helpers were
not installed. Graphical playtesting was not performed, and external upload/PR creation
remains pending. Checklist items requiring those actions are not claimed complete.
