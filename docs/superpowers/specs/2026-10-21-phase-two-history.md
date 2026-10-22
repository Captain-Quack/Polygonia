# Phase Two: an organism with a history

Approved scope: extend existing survival and food-sharing behavior with bounded spatial,
episodic, social, and outcome memory. Identical present conditions and temperament must
produce different choices when experience differs. History must be inspectable and
revisable. Keep player control indirect and avoid relationship labels.

## Architecture

AgentExperienceMemory owns sparse place/individual/action evidence and 32 salient
episodes. AgentCognition translates observations and completed outcomes into evidence,
scores resource options and remembered destinations, and explains actual influences.
Existing action, interaction, combat and navigation systems remain authoritative for
physical effects. Personality is stable; memories never mutate temperament or nutrition.

Place patches are 2 world cells wide, independent of room identifiers. Caps: 64 places,
64 remembered resource capabilities, 24 significant individuals, 16 action preferences,
32 episodes. Continuous encounters coalesce; familiarity accumulates at most once per
second. Evidence decays with simulation time, not rendered frames. Direct experience
has greater weight than witnessing. Safe revisits can revise danger. Help/harm remain
separate so generosity and distrust may coexist. Do not infer refusal or culpability
from mere proximity. Failed or cancelled meals provide no nutrition success.

Food sharing incorporates remembered help/harm and scarcity while retaining finite
portion conservation, immediate threat priority, zero-kindness behavior and reservation
rules. Learned expectations affect resource rankings, exploration and bounded route
alternatives. New evidence interrupts stale preferences; hysteresis retains intentions.

## Performance and knowledge

Spatial indices narrow perception candidates; final visibility remains observer-specific.
Agent IDs have a direct lookup. Bounded route caches invalidate on traversal/radius
changes and expire; active routes are reused. A fair population-wide A* work budget
returns DEFERRED when exhausted. Deferred computation is not an environmental setback,
unreachable food, or permission for predation. Preserve combat and fixed 0.1 s steps.
World edits invalidate physical caches without inserting facts into personal memories.
No per-agent strings are required for memory updates; detailed inspection is on demand.

## Persistence and scope

Versioned JSON-safe cognition snapshots preserve evidence and relative ages and reject
malformed/nonfinite/oversized input atomically. Full-world saves and their UI are outside
this change. No language model, dialogue, carrying, gossip, new needs hierarchy, or
categorical friendship labels. Maslow's 1943 qualifications motivate overlapping needs
and historical effects; numerical learning rules are game design, not clinical claims.

## Acceptance

Controlled opposite histories select opposite equivalent opportunities; swapping memory
swaps preference; clearing memory restores baseline; counterexperience revises beliefs.
Real sharing, meals, attacks, witnessing, failed access and exploration feed memories.
No unseen event learning, stale target tracking, episode-per-tick inflation or unbounded
storage. Codec roundtrips at a shifted clock preserve decisions. Spatial queries match
a brute-force oracle. Work-budget exhaustion cannot manufacture desperation or aggression.
Run all existing tests plus new history/work-budget suites, then compare baseline and
final same-engine headless benchmarks. Report measurements and graphical limits honestly.
