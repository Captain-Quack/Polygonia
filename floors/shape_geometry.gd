@tool
extends RefCounted
## Render geometry only. Stored cell coordinates are never rounded or displaced.

static func rounded_loop(raw: PackedVector2Array, radius: float, steps: int = 6) -> PackedVector2Array:
	var points := PackedVector2Array()
	# Remove straight-through vertices before rounding, including cyclic joins.
	for i in range(raw.size()):
		var before := raw[i] - raw[(i - 1 + raw.size()) % raw.size()]
		var after := raw[(i + 1) % raw.size()] - raw[i]
		if absf(before.cross(after)) > 0.00001 or before.dot(after) <= 0:
			points.append(raw[i])
	if points.size() < 3 or radius <= 0:
		return points
	var rounded := PackedVector2Array()
	for i in range(points.size()):
		var corner := points[i]
		var previous := points[(i - 1 + points.size()) % points.size()]
		var next := points[(i + 1) % points.size()]
		var distance := minf(radius, minf(corner.distance_to(previous), corner.distance_to(next)) * 0.49)
		var a := corner.move_toward(previous, distance)
		var b := corner.move_toward(next, distance)
		for j in range(maxi(steps, 2) + 1):
			var t := float(j) / maxi(steps, 2)
			rounded.append(a * (1-t) * (1-t) + corner * 2 * (1-t) * t + b * t * t)
	return rounded

## Even-odd scan conversion supports holes and disconnected islands. Every band
## is filled once, so translucent fills do not darken at rectangle overlaps.
static func fill_bands(loops: Array) -> Array[PackedVector2Array]:
	var levels := {}
	var edges: Array[Vector4] = []
	for loop in loops:
		for i in range(loop.size()):
			var a: Vector2 = loop[i]
			var b: Vector2 = loop[(i + 1) % loop.size()]
			levels[a.y] = true
			if absf(a.y - b.y) > 0.0001:
				edges.append(Vector4(a.x, a.y, b.x, b.y))
	var ys: Array = levels.keys()
	ys.sort()
	var result: Array[PackedVector2Array] = []
	for i in range(ys.size() - 1):
		var low: float = ys[i]
		var high: float = ys[i + 1]
		# Equivalent curve samples can differ by float roundoff. Such bands
		# have no drawable area and Godot cannot triangulate them.
		if high - low <= 0.0001:
			continue
		var middle := (low + high) * 0.5
		var active: Array[Vector4] = []
		for edge in edges:
			if middle > minf(edge.y, edge.w) and middle < maxf(edge.y, edge.w):
				active.append(edge)
		active.sort_custom(func(a: Vector4, b: Vector4): return _x_at(a, middle) < _x_at(b, middle))
		for j in range(0, active.size() - 1, 2):
			result.append(PackedVector2Array([
				Vector2(_x_at(active[j], low), low), Vector2(_x_at(active[j+1], low), low),
				Vector2(_x_at(active[j+1], high), high), Vector2(_x_at(active[j], high), high)]))
	return result

static func _x_at(edge: Vector4, y: float) -> float:
	return lerpf(edge.x, edge.z, (y - edge.y) / (edge.w - edge.y))

static func round_stroke(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float, closed: bool = false) -> void:
	if points.size() < 2:
		return
	var path := points.duplicate()
	if closed:
		path.append(path[0])
	canvas.draw_polyline(path, color, width, true)
	# Cover flat caps/joins with disks. With solid ink these form continuous round joins.
	for point in points:
		canvas.draw_circle(point, width * 0.5, color, true, -1.0, true)
