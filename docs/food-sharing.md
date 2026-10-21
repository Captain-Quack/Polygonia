# Food claims, sharing, and competition

Placed food still supplies a total of 0.45 nourishment by default. Its three circles now represent three morsels within that serving. A holder can give away one circle, leaving a two-circle pile, and give away another to produce three separate single-circle piles. Each circle supplies one third of the original serving's effects. The split piles are independent world objects and disappear after consumption. The original meal duration is retained for each pile.

Kindness is a stable seeded personality trait, exposed in Polygon inspection. A kind, adequately nourished holder can share with a visibly hungry neighbor within contact range. More visibly hungry neighbors are considered first. Sharing keeps at least one circle, preserves the donor's admission and meal progress, and immediately reserves the new pile for its recipient. A half-second cooldown separates donations. Threatened holders concentrate on their safety. Corpses, rest places, and unlimited resources do not participate in food splitting.

An aggressive agent under extreme food pressure can challenge a visible holder when no timely, unclaimed food is known. Food competition uses the existing deprivation/desperation thresholds independently of the predation toggle. The challenger approaches the observed food and uses existing contact combat, cooldowns, sight checks, and simultaneous damage resolution. A holder's existing fight-or-flight evaluation decides whether to defend or flee. Defense retains the food claim and pauses meal progress; returning to that same meal resumes it. Fleeing releases the claim so another agent can take the food. Competition does not create food or give nutrition on an interrupted meal.

Knowledge remains local: sharing and challenges require current visibility, and walls block both. Moving/removing a resource cancels stale attempts. Recipient death, removal, and action cancellation release uneaten split food. A food contest takes priority over corpse-seeking predation; active threats still take priority over food contests. Route assessment for contests is bounded to four candidates, and superseded prey routes are skipped.

Rendering uses cached layouts for three, two, one, and zero circles. Admitted food is drawn slightly above its world position to remain visible beside its eater. Recent events explain donations, received portions, and food taken after a holder gives way. No new bitmap textures, per-circle nodes, or particle systems are needed.

## Verification

Run `python3 tests/run_tests.py /path/to/godot`. Focused suites cover portion/effect conservation, repeated splits, claims, cancellation and reclamation, seeded kindness, autonomous sharing, contests, defense and surrender, freely available food, wall occlusion, moved/deleted food, meal resumption after defense, and circle layouts.

Numerical thresholds are simulation tuning. Sharing is local and opportunistic; carrying food, requests/negotiation, relationships, and social obligations remain outside this change.
