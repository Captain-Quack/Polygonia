# Circle construction and shared filled floor

User asks for a full implementation improving the circle brainstorming. Center snaps to active grid intersections; radius rounds to active grid multiples using Euclidean distance from the snapped endpoint. Step remains frozen during drag. Zero radius does nothing. Preview shows cardinal extents, center and actual radial guide/label. Filled circles and rectangles use shared paint/erase semantics; Line remains independent.

Keep compact integer rectangle storage until first polygon edit. Promote rectangles into a shared non-overlapping convex polygon region set in base-cell coordinates. Polygon paint/erase use a scan-band boolean sweep: split at vertex and edge-intersection heights, then union/subtract X intervals. Each edit replaces prior fragments with disjoint convex trapezoids. Shared horizontal spans cancel to extract exterior/hole contours without internal seams. Renderer continues drawing disjoint fill bands with a single contour outline, avoiding darker overlaps. Smooth curve samples are not rounded as square corners.

Circle polygon approximation uses deterministic segment count, multiples of four, at least 64 segments, adjustable accuracy and maximum count. Cardinal points are exact. Segment choice depends on world geometry, never zoom; preview and commit share geometry. Large circles are bounded by segment cap, not cell allocation. Generic previews may supply guide paths/markers/text; editor has no Circle branch.

Line and Square APIs, typed Inspector resources, menu anchoring and camera behavior remain. Contains(cell) tests cell-center occupancy in polygon mode; contains_point provides precise point queries for future agent use. Reject invalid polygon input rather than corrupting floor state. No persistence, navigation or room recognition in this task.

Tests cover radius/snapping, coarse/negative positions, geometry agreement, nested holes/islands, circle-square edits both directions, tangencies, deterministic mixed operations against point occupancy oracle, line independence, renderer topology, integrated registration and input/cancellation. Delivery is a feature branch and reviewable PR based on merged main.

Precision: geometry calculations use a local origin; contour keys use 64-bit integer text, quantized at 0.0001 base cells. Engine Vector2 remains single precision at extreme world coordinates. Curve chord error is a target; max_segments caps cost and may exceed the target for large circles. Native rendering triangulates each thin fill band near its own origin to avoid cancellation.
