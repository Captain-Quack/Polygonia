# Emergency behavior design

Status: proposed specification for user review. Implementation has not begun.

## Intent and success

Polygonia is an autonomous social simulation with simple graphics and rich observable behavior. The player changes the world, not agent commands. Emergency behavior must emerge from bodily needs, limited knowledge, history, and individual traits. It must remain extensible as objects and social behavior are added.

The agreed approach combines continuous urgency with accumulated impairment. Urgency and capability are separate: deprivation increases the importance of nourishment while potentially impairing the ability to obtain it. Ordinary rest must work without causing avoidable starvation. Extreme attacks on living agents remain possible, contingent on circumstances and traits.

Success means reproducible, explainable decisions, correct resource accounting, meaningful individual differences, and no omniscient resource or target tracking. Survival is not guaranteed when relief is genuinely unavailable or too late.

## Evidence and interpretation

Reference: Spettigue et al. (2025), The Psychological, Cognitive, and Behavioural Effects of Starvation in Humans: A Scoping Review. https://doi.org/10.1002/erv.3174 . Full text inspected at https://onlinelibrary.wiley.com/doi/full/10.1002/erv.3174 .

The review supports associations between malnutrition and cognitive impairment, anxiety, depression, social withdrawal, and disturbed sleep. Historical research discussed in the review includes food preoccupation and irritability. Its heterogeneous populations, causal uncertainty, and lack of individual study quality appraisal preclude a universal behavioral progression or numerical calibration.

All thresholds, equations, trait distributions, recovery times, attack rules, and simulated time scales below are authored simulation choices, not clinical predictions. Cannibalism is a fictional species mechanic, not an inference from this paper. Do not label agents with psychiatric diagnoses. Social withdrawal is reserved for future social actions; do not build an unused social subsystem now. Detailed sleep physiology and medical refeeding complications are outside this increment.

## Boundaries and data flow

- `BodyState`: current nourishment, fatigue, health, accumulated deprivation; applies physical effects and determines death.
- `EmergencyProfile` Resource: validated tunable rates, limits, and policy parameters. Defaults preserve existing hunger and starvation rates until explicitly changed by verification.
- `Personality`: persistent caution, persistence, and aggression values in [0,1]. Stable seeded assignment, never rerolled per decision; fixtures can supply exact values.
- `EmergencyAssessment`: pure calculation from body and profile into urgency, impairment, mobility modifier, and estimated time to fatal deprivation under current physiology.
- `MotivationSystem`: converts assessment and traits into food, rest, exploration, and threat priorities. Produces explanations alongside weights.
- `DecisionSystem`: generates feasible candidates from beliefs and combines expected relief, time, uncertainty, and risk. It does not apply physical effects.
- `PerceptionSystem` and beliefs: retain object snapshots; add observed agent snapshots for threats/prey, without remote truth updates.
- `ActionController`: handles cancellation and dispatches actions. Extract combat execution into a small handler rather than expanding the existing match indefinitely.
- `CombatSystem`: validates and resolves queued attacks and finite nourishment transfer. Owns no motivation policy.

Tick order: update all bodies; cancel dead agents; perceive and assess living agents; choose intentions; execute movement and interactions; resolve queued attacks together; clean up deaths and depleted objects. Use a stable per-tick snapshot for combat resolution so iteration order cannot grant immunity by killing an attacker first. Resource reservation ties remain deterministic; fair allocation is separate scope.

## Physiological state

Keep current hunger, fatigue, starvation damage, and completed-meal semantics. Accumulated deprivation D is normalized [0,1]. Initial proposed defaults: below nourishment 0.25, D increases by ((0.25 - nourishment) / 0.25) / 120 per simulated second. At nourishment at least 0.40, D decreases by 1/180 per second; between those boundaries it remains stable. These explicit recovery boundaries prevent repeated tiny meals from instantly clearing impairment.

Urgency depends on nourishment and actual ongoing harm relative to remaining health. Compute time to fatal starvation using the current nourishment drain and piecewise starvation-damage curve, including time until damage begins. Handle zero drain, zero damage, and zero health without NaN or division by zero. This estimate is a simulation assessment, not literal knowledge that an agent has of its death time.

Impairment follows D continuously. Initial mobility penalty is bounded to 25% in addition to the current fatigue penalty, leaving movement possible while alive. No new fatigue damage, unconsciousness, or collapse in this increment. Health does not regenerate in this increment; refed agents retain injury and its effect on risk assessment.

## Decisions and interruption

For each remembered food candidate estimate time to first relief: travel along a currently validated route at effective speed plus remaining interaction duration. Reuse route calculations across a decision and invalidate on traversal or observed target revision changes. Do not run unlimited path searches. Unvalidated routes carry uncertainty, never a claim of reachability.

Assess predicted health at first relief. When death is projected before the current non-food action followed by feeding, urgently reconsider. Prefer feasible feeding that arrives before death over optional rest. In equally survivable choices, ordinary utility, confidence, and personality still matter. A shorter route is not automatically better than a route to much more useful nourishment.

If no known food is viable, increase food-search motivation with urgency. A recently fed tired agent can rest; a severely deprived agent should search rather than repeat long rest sessions solely because fatigue is high. Allow only a bounded recovery break when its speed gain makes the predicted route plus break faster or necessary for the selected action; the current physiology may make such breaks rarely worthwhile. Never invent knowledge of unseen food.

Retain hysteresis for ordinary choices. Imminent harm and direct attack bypass it and cause reconsideration by the next fixed simulation tick. Preserve progress on the same target. Do not interrupt an almost-complete meal for an equivalent alternative. Cancelled food interactions provide no partial nourishment, and their reservations are released. A meal whose completion is too late may still be attempted if it is the best remaining chance; do not manufacture rescue effects.

Known blocked routes keep bounded retry cooldowns. A relevant traversal change enables immediate reconsideration. Impairment may favor familiar sources but cannot override a current observation that the source is gone or a fresh confirmed route failure.

## Impairment and variation

Food preoccupation increases the relative weight of nourishment and food-directed exploration. Impairment adds bounded preference for familiar options and reduces the number of alternative destinations considered, with a minimum of two where alternatives exist. Keep emergency reconsideration latency unchanged: impairment must not disable processing of an attack or resource removal.

Persistent personality values modulate risk cost, familiar-target persistence, and willingness to attack. Any stochastic tie-breaking uses a simulation-owned seeded random source; never per-frame noise. Stable inputs should produce stable intentions and smooth motion. Impairment changes gradually with D, so one meal relieves immediate hunger without instantly resetting behavior.

## Extreme aggression and defense

Enable through an explicit profile setting, on by default for the agreed species behavior. Attacking for nourishment becomes eligible only with D at least 0.65, nourishment below 0.10, positive starvation damage, and no perceived ordinary food option expected to provide timely relief. Eligibility does not force selection. Aggression lowers attack aversion; caution increases expected injury cost. A zero-aggression fixture must be able to reject predation despite eligibility.

Targets must be living, perceived within normal sight and line of sight, and reachable. Use observed position and visible condition estimates, not hidden exact health or remote movement. Replan pursuit only from new observations. Losing sight allows movement to the last observed location, then a bounded local search, never live tracking through walls. A newly feasible ordinary food option triggers reevaluation and may end pursuit.

Initial tunable combat defaults: contact distance equals both radii plus 0.10 cells; strike interval 1 second; base damage 0.10 health per strike, reduced by attacker impairment. Validate range, line of sight, actor/target existence, and life state when strikes resolve. No damage through walls, during cooldown, or after removal.

Direct attacks create an immediate perceived threat and interrupt ordinary actions. Prefer reachable escape destinations that increase separation from visible attackers, using existing collision-aware navigation. If no escape candidate is feasible, defend against a reachable attacker. Defensive retaliation grants no feeding intent automatically. Resolve simultaneous strikes from the same pre-resolution snapshot and apply aggregate damage once.

For this increment, nourishment from predation occurs only after a successful kill, not on each hit. Each agent has a finite edible yield, initially 0.45 nourishment. A successful feeding-intent killer can begin a two-second consumption interaction at the corpse through the ordinary reservation mechanism; survivors and other eligible predators may discover the same remaining resource. Emit one corpse resource per death with its own stock and provider, including starvation deaths. It replaces the dead body visually and collision-wise so there are not two occupiable copies. Corpse consumption is restricted to extreme feeding eligibility in this increment. Concurrent killers cannot duplicate yield. Removal interrupts use, and depletion removes the resource. A full corpse inventory, carrying, and dismemberment are out of scope.

## Inspection and presentation

Keep rounded triangle agents and continuous movement. Inspection displays current action, urgency, accumulated deprivation, impairment, target, and the main reason for the last choice. Use concrete event text such as 'Interrupted rest: food cannot wait', 'Lost sight of target', or 'Fled an attack'. Avoid moral or relationship labels. Show extreme pursuit, fleeing, eating, resting, and death distinctly using existing minimal rendering conventions. Diagnostics may expose exact values; ordinary action labels should remain readable.

## Verification and acceptance

Use seeded headless scenarios, physiological unit checks, and an interactive scene check. Parameterize representative health, fatigue, distance, deprivation, and trait values. Assert effects and decision reasons, not survival alone.

1. Reproduce the pending rest regression: nourishment zero, fatigue one, health 0.12, food three cells away, rest underfoot. With no preexisting impairment, pursue food promptly and survive under current rates.
2. Different remaining health produces different urgency and, in a constructed food/rest conflict, different choices.
3. With unknown food outside perception and severe deprivation, leave rest and search; do not assert guaranteed discovery in an arbitrary world.
4. Unreachable, moved, depleted, and removed food produce bounded retries and release reservations; reopening a route permits reconsideration.
5. An interrupted or fatal meal grants no nutrition; food is consumed exactly once on successful completion.
6. Normal fatigue still produces a complete rest session; emergency interruption releases its capacity. Ground rest remains a valid fallback.
7. Equal current hunger with different deprivation histories produces different impairment; sustained nourishment reduces D gradually. Bounds hold across time-step variations.
8. Ordinary hunger never permits predation. Extreme eligibility alone does not force every trait profile to attack. Timely ordinary food suppresses predation.
9. Threats interrupt by the next fixed tick; escape respects walls and locked doors; trapped agents can defend. No targeting unseen live positions.
10. Attack cooldown, contact checks, simultaneous lethal strikes, removed targets, and death cancellation preserve invariants. Exactly one finite corpse yield exists per agent; simultaneous consumers cannot duplicate it.
11. Same seed and starting state reproduce outcomes. Combat outcome is invariant to agent list order for simultaneous strikes; document that ordinary food reservation ties remain ordered.
12. Re-run the entire existing suite and startup checks. Manually inspect movement, state changes, and corpse presentation; report headless-only verification if interactive testing is unavailable.

## Delivery and scope

Build in independently verified increments: emergency assessment and survival choices; accumulated impairment and traits; threat perception, combat, and finite corpse interactions; inspection and integrated verification. These are one approved design with isolated implementation checkpoints, not unrelated feature expansion.

Preserve the local rest improvements and verify them with the new emergency cases before delivery. No external upload or merge is performed by this specification. Research does not calibrate exact game parameters: keep them centralized and describe adjustments as tuning. Do not add construction by agents, social relationships, sharing, stealing, health regeneration, full sleep cycles, or long-term psychiatric states in this work.
