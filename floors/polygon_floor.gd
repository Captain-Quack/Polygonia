extends RefCounted
## Filled floor represented by disjoint convex scan bands, in base cells.
## Boolean edits split at every vertex/intersection height and sweep X intervals.
## This handles holes and islands without per-cell allocation or clip fragments.
const EPS := 0.00001
const KEY_SCALE := 10000.0
var pieces: Array[PackedVector2Array] = []
var _loops: Array = []
var _dirty := true

static func rect_polygon(rect: Rect2i) -> PackedVector2Array:
	return PackedVector2Array([Vector2(rect.position), Vector2(rect.end.x, rect.position.y), Vector2(rect.end), Vector2(rect.position.x, rect.end.y)])

func apply_polygon(raw: PackedVector2Array, erase: bool) -> bool:
	var polygon := _clean(raw)
	if polygon.size() < 3 or absf(_signed_area(polygon)) <= EPS or not _is_simple(polygon):
		return false
	# A shared local origin preserves precision for operations far from (0,0).
	var origin := polygon[0].floor()
	var levels := {}
	var old_edges: Array[Vector4] = []
	var cut_edges: Array[Vector4] = []
	for piece in pieces:
		_edges(_translated(piece, -origin), levels, old_edges)
	_edges(_translated(polygon, -origin), levels, cut_edges)
	# Boundaries may change X order at a crossing. Its height must split a band.
	for first in old_edges:
		for second in cut_edges:
			var point = Geometry2D.segment_intersects_segment(Vector2(first.x,first.y), Vector2(first.z,first.w), Vector2(second.x,second.y), Vector2(second.z,second.w))
			if point != null:
				levels[roundi(point.y * KEY_SCALE)] = true
	var ys: Array = levels.keys()
	ys.sort()
	var next: Array[PackedVector2Array] = []
	for index in range(ys.size() - 1):
		var low: float = float(ys[index]) / KEY_SCALE
		var high: float = float(ys[index + 1]) / KEY_SCALE
		if high - low <= EPS:
			continue
		var middle := (low + high) * 0.5
		var events: Array = []
		_events(old_edges, middle, true, events)
		_events(cut_edges, middle, false, events)
		events.sort_custom(func(a: Array, b: Array): return a[0] < b[0])
		var old_count := 0
		var cut_count := 0
		var left := Vector4()
		var event_index := 0
		while event_index < events.size():
			var before := (old_count > 0 and cut_count == 0) if erase else (old_count > 0 or cut_count > 0)
			var first: Array = events[event_index]
			var boundary: Vector4 = first[3]
			while event_index < events.size() and absf(events[event_index][0] - first[0]) <= EPS:
				old_count += events[event_index][1]
				cut_count += events[event_index][2]
				event_index += 1
			var after := (old_count > 0 and cut_count == 0) if erase else (old_count > 0 or cut_count > 0)
			if not before and after:
				left = boundary
			elif before and not after:
				var band := _clean(PackedVector2Array([
					Vector2(_x_at(left,low),low), Vector2(_x_at(boundary,low),low),
					Vector2(_x_at(boundary,high),high), Vector2(_x_at(left,high),high)]))
				if band.size() >= 3 and absf(_signed_area(band)) > EPS:
					next.append(_translated(band, origin))
	pieces = next
	_dirty = true
	return true

static func _edges(polygon: PackedVector2Array, levels: Dictionary, edges: Array[Vector4]) -> void:
	for index in range(polygon.size()):
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		levels[roundi(a.y * KEY_SCALE)] = true
		if absf(a.y - b.y) > EPS:
			edges.append(Vector4(a.x,a.y,b.x,b.y))

static func _events(edges: Array[Vector4], middle: float, old: bool, events: Array) -> void:
	var active: Array[Vector4] = []
	for edge in edges:
		if middle > minf(edge.y,edge.w) and middle < maxf(edge.y,edge.w):
			active.append(edge)
	active.sort_custom(func(a: Vector4, b: Vector4): return _x_at(a,middle) < _x_at(b,middle))
	# Current pieces have non-overlapping interiors; even-odd also supports a
	# concave incoming polygon. Shared adjacent spans cancel in the X sweep.
	for index in range(active.size()):
		var delta := 1 if index % 2 == 0 else -1
		events.append([_x_at(active[index],middle), delta if old else 0, 0 if old else delta, active[index]])

static func _x_at(edge: Vector4, y: float) -> float:
	return edge.x + (edge.z - edge.x) * ((y - edge.y) / (edge.w - edge.y))

func contains_point(point: Vector2) -> bool:
	for piece in pieces:
		if Geometry2D.is_point_in_polygon(point - piece[0], _translated(piece,-piece[0])):
			return true
	return false

static func _signed_area(polygon: PackedVector2Array) -> float:
	var origin := polygon[0]
	var area := 0.0
	for i in range(polygon.size()):
		area += (polygon[i] - origin).cross(polygon[(i + 1) % polygon.size()] - origin)
	return area * 0.5

static func _clean(raw: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in raw:
		if not point.is_finite():
			return PackedVector2Array()
		if result.is_empty() or point.distance_squared_to(result[-1]) > EPS * EPS:
			result.append(point)
	if result.size() > 1 and result[0].distance_squared_to(result[-1]) <= EPS * EPS:
		result.remove_at(result.size() - 1)
	return result

static func _translated(polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := polygon.duplicate()
	for i in range(result.size()):
		result[i] += offset
	return result

static func _is_simple(polygon: PackedVector2Array) -> bool:
	var local := _translated(polygon, -polygon[0])
	for i in range(local.size()):
		var a := local[i]
		var b := local[(i + 1) % local.size()]
		for j in range(i + 1, local.size()):
			if j == i + 1 or (i == 0 and j == local.size() - 1):
				continue
			var c := local[j]
			var d := local[(j + 1) % local.size()]
			if Geometry2D.segment_intersects_segment(a,b,c,d) != null:
				return false
			if c.distance_to(Geometry2D.get_closest_point_to_segment(c,a,b)) <= EPS or a.distance_to(Geometry2D.get_closest_point_to_segment(a,c,d)) <= EPS:
				return false
	return true

static func _key(point: Vector2) -> String:
	# Strings contain 64-bit coordinates; Vector2i would overflow when scaled.
	return "%d,%d" % [roundi(point.x * KEY_SCALE), roundi(point.y * KEY_SCALE)]

static func _point(key: String) -> Vector2:
	var components := key.split(",")
	return Vector2(float(components[0]) / KEY_SCALE, float(components[1]) / KEY_SCALE)

func boundary_loops() -> Array:
	if not _dirty:
		return _loops
	_dirty = false
	_loops = []
	var horizontal := {}
	var boundary := {}
	for piece in pieces:
		for i in range(piece.size()):
			var a := piece[i]
			var b := piece[(i + 1) % piece.size()]
			var first := _key(a)
			var last := _key(b)
			if first == last:
				continue
			if absf(a.y-b.y) <= EPS:
				var y := roundi(a.y * KEY_SCALE)
				if not horizontal.has(y):
					horizontal[y] = {}
				var events: Dictionary = horizontal[y]
				var x1 := roundi(a.x * KEY_SCALE)
				var x2 := roundi(b.x * KEY_SCALE)
				var sign_value := 1 if x2 > x1 else -1
				var low := mini(x1,x2)
				var high := maxi(x1,x2)
				events[low] = events.get(low,0) + sign_value
				events[high] = events.get(high,0) - sign_value
			else:
				var backward := last + ":" + first
				if boundary.has(backward):
					boundary.erase(backward)
				else:
					boundary[first + ":" + last] = [first,last]
	# Cancel shared horizontal spans, splitting endpoints at T junctions.
	for y in horizontal:
		var events: Dictionary = horizontal[y]
		var xs: Array = events.keys()
		xs.sort()
		var total := 0
		for i in range(xs.size()-1):
			total += events[xs[i]]
			if total == 0:
				continue
			var first := "%d,%d" % [xs[i],y]
			var last := "%d,%d" % [xs[i+1],y]
			if total < 0:
				var swap := first
				first = last
				last = swap
			boundary[first + ":" + last] = [first,last]
	var outgoing := {}
	for id in boundary:
		var edge: Array = boundary[id]
		if not outgoing.has(edge[0]):
			outgoing[edge[0]] = []
		outgoing[edge[0]].append(id)
	var visited := {}
	for first in boundary:
		if visited.has(first):
			continue
		var loop := PackedVector2Array()
		var id: String = first
		var origin: String = boundary[first][0]
		var closed := false
		while not visited.has(id):
			visited[id] = true
			var edge: Array = boundary[id]
			var start: String = edge[0]
			var end: String = edge[1]
			loop.append(_point(start))
			if end == origin:
				closed = true
				break
			var direction := _point(end) - _point(start)
			var best := -INF
			var next := ""
			for candidate in outgoing.get(end,[]):
				if visited.has(candidate):
					continue
				var other: Array = boundary[candidate]
				var turn := direction.angle_to(_point(other[1]) - _point(other[0]))
				if turn > best:
					best = turn
					next = candidate
			if next.is_empty():
				push_error("Polygon floor contour did not close.")
				break
			id = next
		if closed and loop.size() >= 3:
			_loops.append(loop)
	return _loops
