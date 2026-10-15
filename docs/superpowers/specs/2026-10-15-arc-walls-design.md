# Arc walls

The user requests replacing Circular Wall with Arc Wall to enclose mixed curved/straight shapes such as the supplied circle-and-corridor floor. Existing Door must continue to work on curved walls. Full circles remain a special case.

Arc Wall uses three clicks: snapped center, radius/start point, end point. Grid spacing stays frozen through the gesture. Endpoints project onto the shared Circle floor sampling; nearby floor-outline vertices and existing wall intersections provide exact join targets. Shift selects the opposite sweep. Selecting the start again produces a full circle. Escape, focus loss, tool/mode switching or conflicting UI clicks cancel without edits. Preview shows center, radii, endpoints, sweep direction/angle and the exact geometry to commit.

Generalize compact circle hosts with normalized occupied boundary-distance intervals. Union painting and partial erasure are atomic and retain host IDs while any arc remains. Straight wall endpoints may snap to curve endpoints without integer truncation. Geometry, collision, room boundaries, portals and the same Door tool use only occupied intervals. Doors cannot cross missing arc ends. Erasing a whole aperture removes its door; partial support erasure rejects the entire edit. Preserve schema 1/2 worlds; schema 3 represents partial intervals and fractional orthogonal wall endpoints. Existing circles load as full ranges.

Tests reproduce partial enclosure, complementary arcs forming rooms, seam wrapping, arc union/subtraction, matching floor/straight joins, mixed fractional walls, curved door support, stale proposals, staged input/cancellation and serialization. Preserve legacy floor/line controls and original Circle floor behavior. Published changes use a reviewable branch; no merge is performed.
