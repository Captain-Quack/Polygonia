# Circular walls and shared door tool

User approved smooth circular walls matching the existing Circle tool and explicitly requires the same Door tool to place doors on curved walls.

Add a Circular Wall resource handler to Structures. Center and radius use the existing Circle gesture and frozen visible snap grid. Use the same sampled boundary as Circle floors. Store circles as compact authoritative primitives, not unrelated wall fragments. Existing straight walls and floor lines keep their current semantics. Repainting the same circle is a no-op; right-dragging the same center/radius removes the loop and its doors atomically.

The Door tool projects to either a straight wall or a circular boundary. Circular doors occupy one base cell measured along the sampled boundary, can span its sample vertices and seam, and use the existing open/close/lock/erase interactions. Door metadata anchors to a circle ID and boundary distance so its curved aperture is derived deterministically. Opening removes the entire aperture from barriers. Closing restores its curved leaf. Clearance, visibility, occupancy callbacks and previews consume the same path. Ambiguous targets and wall crossings through door interiors reject atomically.

Physical and region systems consume a shared expansion of primitives into segments. Extend half-edge arrangement intersections and area to arbitrary sampled segments; preserve exact straight integer fixtures. Region overlays and lineage must support sloping boundaries and holes. Structural enclosure remains independent of coverage and social meaning.

Codec version 2 adds circle primitives and circle-anchored door parameters. Continue reading version 1 and preserve its encoding for straight-only worlds. Validate references, coordinate limits, circle extent, segment count and aperture parameters. No freehand arcs, arbitrary rotation tool, circle trimming, or new agent behaviors in this addition.

Verification: failing circular-tool integration test; circle room area, exterior, walls joining/splitting circles, nested/overlapping circles; seam and oblique doors, actual clearance/sight, lock/occupancy, stale proposals, erasure/restore and codec compatibility. Run all existing suites, import/startup, and independent code review before publishing a separate PR after PR #4 was merged. Graphical/Godot 4.7 verification remains unavailable on this host.
