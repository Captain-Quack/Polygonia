# Phase One: autonomous survival

Approved conversation scope: rounded-triangle Polygons perceive and remember food,
navigate, eat finite portions, grow hungry, and lose health under severe deprivation.
Include early fatigue and rest, with ground rest as fallback. No combat, cannibalism,
relationships, personality simulation, inventory or day/night routines in this phase.

## Boundaries
Use Godot 4 GDScript, existing base-cell coordinates and PhysicalQueries. Separate
configurable BodyState, beliefs/perception, utility selection, action execution,
navigation, simulation orchestration and drawing. Objects separate shared definition,
instance identity/state, and multiple interaction providers. Providers validate access,
capacity and resource availability at execution; cancellation must release reservations.
World truth never updates an unseen resource belief. Navigation may know geometry.

## Runtime
Fixed 0.1 simulation-second steps, pause and speed controls. Nourishment/fatigue/health
are normalized 0..1; hunger is 1-nourishment. Hunger urgency is nonlinear. Deprivation
below 0.1 nourishment damages health; zero health stops action and releases resources.
Food interactions take time; concurrent agents cannot consume the same portion.
Rest reduces fatigue, including slower ground rest. Stronger alternatives interrupt
current plans with hysteresis. Perception uses distance and blocked line of sight.
Remember last observed locations and failed attempts; retry after cooldown or traversal
revision changes. Explore deterministically when hungry and no usable source is known.

## Navigation
Use bounded half-cell A* with swept body clearance and explicit no-route results.
Honor straight/curved walls and locked doors; agents can open unlocked doors through
existing structure commands. Recheck movement against current barriers. Search bounds
and expansion budgets are explicit prototype limitations, not proof of global isolation.

## Integration
Register Agent, Food and Rest construction tools through existing categories/handlers.
Right-click removes the selected kind. Add object move tool to exercise unseen relocation.
Provide selection/inspection and pause/speed without commanding agent goals. Live state
is session-only; existing structure persistence remains structure-only.

## Acceptance
Headless scenarios: hunger and starvation, dead agents cannot act, food depletion and
competition, observation-limited relocation, removal during eating, rest and fatigue,
wall detours, closed/open/locked doors, curved barriers and traversal invalidation.
Run existing regression suite and scene startup. Document how to try and extend.
