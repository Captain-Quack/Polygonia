extends RefCounted
## Non-overlapping rectangles in BASE-cell coordinates; empty space costs nothing.
signal changed
var regions: Array[Rect2i] = []

func subtract(source: Rect2i, cut: Rect2i) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var overlap := source.intersection(cut)
	if not overlap.has_area():
		return [source]
	var pieces := [
		Rect2i(source.position, Vector2i(source.size.x, overlap.position.y - source.position.y)),
		Rect2i(Vector2i(source.position.x, overlap.end.y), Vector2i(source.size.x, source.end.y - overlap.end.y)),
		Rect2i(Vector2i(source.position.x, overlap.position.y), Vector2i(overlap.position.x - source.position.x, overlap.size.y)),
		Rect2i(Vector2i(overlap.end.x, overlap.position.y), Vector2i(source.end.x - overlap.end.x, overlap.size.y))]
	for piece in pieces:
		if piece.has_area():
			result.append(piece)
	return result

func apply_rect(rect: Rect2i, erase: bool) -> void:
	if not rect.has_area():
		return
	var next: Array[Rect2i] = []
	for region in regions:
		next.append_array(subtract(region, rect))
	if not erase:
		next.append(rect)
	regions = next
	changed.emit()

func contains(cell: Vector2i) -> bool:
	for region in regions:
		if region.has_point(cell):
			return true
	return false

## Axis-aligned strokes in exact BASE-cell coordinates: x1, y1, x2, y2.
## They are boundaries, not occupied floor cells. Closed-shape filling can use
## these segments later without having to recover geometry from rendered pixels.
var lines: Array[Vector4i] = []

func apply_line(a: Vector2i, b: Vector2i, erase: bool) -> void:
	if a == b or (a.x != b.x and a.y != b.y):
		return
	var horizontal := a.y == b.y
	var fixed := a.y if horizontal else a.x
	var low := mini(a.x, b.x) if horizontal else mini(a.y, b.y)
	var high := maxi(a.x, b.x) if horizontal else maxi(a.y, b.y)
	var next: Array[Vector4i] = []
	var intervals: Array[Vector2i] = []
	for line in lines:
		var same_axis := (line.y == line.w) == horizontal
		var same_fixed := (line.y if horizontal else line.x) == fixed
		if not same_axis or not same_fixed:
			next.append(line)
			continue
		var lo := line.x if horizontal else line.y
		var hi := line.z if horizontal else line.w
		if not erase or hi <= low or lo >= high:
			intervals.append(Vector2i(lo, hi))
		else:
			if lo < low:
				intervals.append(Vector2i(lo, low))
			if hi > high:
				intervals.append(Vector2i(high, hi))
	if not erase:
		intervals.append(Vector2i(low, high))
	intervals.sort_custom(func(x: Vector2i, y: Vector2i): return x.x < y.x)
	var merged: Array[Vector2i] = []
	for interval in intervals:
		if not merged.is_empty() and interval.x <= merged[-1].y:
			merged[-1] = Vector2i(merged[-1].x, maxi(merged[-1].y, interval.y))
		else:
			merged.append(interval)
	for interval in merged:
		next.append(Vector4i(interval.x, fixed, interval.y, fixed) if horizontal else Vector4i(fixed, interval.x, fixed, interval.y))
	lines = next
	changed.emit()

## Cancel opposing rectangle edges using interval events, with no per-cell map.
## Preserve event endpoints so contours also work at T junctions and corner touches.
func boundary_loops() -> Array:
	var horizontal := {}
	var vertical := {}
	for rect in regions:
		_edge_event(horizontal, rect.position.y, rect.position.x, rect.end.x, 1)
		_edge_event(horizontal, rect.end.y, rect.position.x, rect.end.x, -1)
		_edge_event(vertical, rect.end.x, rect.position.y, rect.end.y, 1)
		_edge_event(vertical, rect.position.x, rect.position.y, rect.end.y, -1)
	var edges: Array[Vector4i] = []
	_sweep_edges(horizontal, true, edges)
	_sweep_edges(vertical, false, edges)
	var outgoing := {}
	for i in range(edges.size()):
		var start := Vector2i(edges[i].x, edges[i].y)
		if not outgoing.has(start):
			outgoing[start] = []
		outgoing[start].append(i)
	var visited := {}
	var loops: Array = []
	for first in range(edges.size()):
		if visited.has(first):
			continue
		var loop: Array[Vector2i] = []
		var current := first
		var origin := Vector2i(edges[first].x, edges[first].y)
		while not visited.has(current):
			visited[current] = true
			var edge := edges[current]
			var start := Vector2i(edge.x, edge.y)
			var end := Vector2i(edge.z, edge.w)
			loop.append(start)
			if end == origin:
				break
			var direction := Vector2(end - start)
			var next := -1
			var best := -INF
			for candidate in outgoing.get(end, []):
				if visited.has(candidate):
					continue
				var other := edges[candidate]
				var turn := direction.angle_to(Vector2(other.z - other.x, other.w - other.y))
				if turn > best:
					best = turn
					next = candidate
			if next < 0:
				break
			current = next
		if loop.size() >= 4:
			loops.append(loop)
	return loops

func _edge_event(table: Dictionary, fixed: int, low: int, high: int, sign_value: int) -> void:
	if not table.has(fixed):
		table[fixed] = {}
	var events: Dictionary = table[fixed]
	events[low] = events.get(low, 0) + sign_value
	events[high] = events.get(high, 0) - sign_value

func _sweep_edges(table: Dictionary, horizontal: bool, edges: Array[Vector4i]) -> void:
	for fixed in table:
		var events: Dictionary = table[fixed]
		var positions: Array = events.keys()
		positions.sort()
		var total := 0
		for i in range(positions.size() - 1):
			total += int(events[positions[i]])
			if total == 0:
				continue
			var low: int = positions[i]
			var high: int = positions[i + 1]
			var a := Vector2i(low, fixed) if horizontal else Vector2i(fixed, low)
			var b := Vector2i(high, fixed) if horizontal else Vector2i(fixed, high)
			if total < 0:
				var swap := a
				a = b
				b = swap
			edges.append(Vector4i(a.x, a.y, b.x, b.y))
