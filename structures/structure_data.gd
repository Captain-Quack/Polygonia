class_name StructureData
extends RefCounted
## Sparse authoritative records. Public accessors return independent value copies.
const LIMIT := 1000000
var _walls: Array = []
var _doors: Array = []
var _circles: Array = []
var next_id := 1
var revision := 0
var topology_revision := 0
var barrier_revision := 0
var traversal_revision := 0
func get_walls() -> Array: return _walls.duplicate(true)
func get_circles() -> Array:return _circles.duplicate(true)
func get_circle(id: int) -> Dictionary:
	for c in _circles:
		if c.id==id:return c.duplicate(true)
	return {}
func circle_points(c: Dictionary) -> PackedVector2Array:
	return CircleBoundary.points(Vector2(c.center),c.radius,c.segments)
func get_wall_segments() -> Array:
	var result=get_walls()
	for c in _circles:
		var points=circle_points(c)
		var offset=0.0
		for i in range(points.size()):
			var a=points[i];var b=points[(i+1)%points.size()]
			result.append({"id":c.id,"circle_id":c.id,"offset":offset,"a":a,"b":b})
			offset+=a.distance_to(b)
	return result
static func door_path(d: Dictionary) -> PackedVector2Array:
	return d.get("path",PackedVector2Array([Vector2(d.a),Vector2(d.b)]))
func get_doors() -> Array:
	var result=_doors.duplicate(true)
	for d in result:
		if not d.has("circle_id"):continue
		var c=get_circle(d.circle_id)
		if c.is_empty():continue
		d.path=CircleBoundary.slice(circle_points(c),d.offset,1.0)
		d.a=d.path[0];d.b=d.path[-1]
	return result
func get_door(id: int) -> Dictionary:
	for door in get_doors():
		if door.id == id: return door.duplicate(true)
	return {}
func copy() -> StructureData:
	var result := StructureData.new()
	result._walls = get_walls()
	result._doors = _doors.duplicate(true)
	result._circles = get_circles()
	result.next_id = next_id
	result.revision = revision
	result.topology_revision = topology_revision
	result.barrier_revision = barrier_revision
	result.traversal_revision = traversal_revision
	return result
func allocate_id() -> int:
	var id := next_id
	next_id += 1
	return id
static func in_range(p: Vector2) -> bool:
	return is_finite(p.x) and is_finite(p.y) and absf(p.x) <= LIMIT and absf(p.y) <= LIMIT
static func valid_segment(a: Vector2i,b: Vector2i) -> bool:
	return in_range(Vector2(a)) and in_range(Vector2(b)) and a != b and (a.x == b.x or a.y == b.y)
static func canonical(a: Vector2i,b: Vector2i) -> Array:
	return [a,b] if a.x < b.x or (a.x == b.x and a.y < b.y) else [b,a]
static func collinear(a: Dictionary,b: Dictionary) -> bool:
	return (a.a.y == a.b.y and b.a.y == b.b.y and a.a.y == b.a.y) or (a.a.x == a.b.x and b.a.x == b.b.x and a.a.x == b.a.x)
static func low(r: Dictionary) -> int: return r.a.x if r.a.y == r.b.y else r.a.y
static func high(r: Dictionary) -> int: return r.b.x if r.a.y == r.b.y else r.b.y
static func subrun(r: Dictionary,lo: int,hi: int) -> Dictionary:
	var s = r.duplicate(true)
	if r.a.y == r.b.y:
		s.a = Vector2i(lo,r.a.y); s.b = Vector2i(hi,r.a.y)
	else:
		s.a = Vector2i(r.a.x,lo); s.b = Vector2i(r.a.x,hi)
	return s
func normalize_walls() -> void:
	var old = _walls.duplicate(true)
	var groups := {}
	for r in _walls:
		var key = "h:%d" % r.a.y if r.a.y == r.b.y else "v:%d" % r.a.x
		if not groups.has(key): groups[key] = []
		groups[key].append(r)
	var result: Array = []
	var keys = groups.keys(); keys.sort()
	for key in keys:
		var runs: Array = groups[key]
		runs.sort_custom(func(a,b): return low(a)<low(b))
		var merged: Array = []
		for r in runs:
			if not merged.is_empty() and low(r)<=high(merged[-1]):
				merged[-1] = subrun(merged[-1],low(merged[-1]),maxi(high(merged[-1]),high(r)))
			else: merged.append(r.duplicate(true))
		for r in merged:
			r.id = 0
			for previous in old:
				if previous.a == r.a and previous.b == r.b and previous.id > 0:
					r.id = previous.id; break
			if r.id == 0: r.id = allocate_id()
			result.append(r)
	_walls = result
func validate() -> StringName:
	var ids := {}
	for r in _walls + _doors:
		if r.has("circle_id"):continue
		if not valid_segment(r.a,r.b) or r.a != canonical(r.a,r.b)[0]: return &"INVALID_SEGMENT"
		if r.id <= 0 or ids.has(r.id) or r.id >= next_id: return &"INVALID_ID"
		ids[r.id] = true
	for r in _walls:
		if r.material != &"solid": return &"INVALID_MATERIAL"
	for i in range(_doors.size()):
		var d = _doors[i]
		if d.state not in [&"OPEN",&"CLOSED"] or (d.state == &"OPEN" and d.locked): return &"INVALID_STATE"
		if d.has("circle_id"):continue
		var supported := false
		for w in _walls:
			if collinear(d,w) and low(w)<=low(d) and high(w)>=high(d): supported = true
			if (d.a.y == d.b.y) != (w.a.y == w.b.y):
				var h = d if d.a.y == d.b.y else w
				var v = w if d.a.y == d.b.y else d
				if v.a.x >= h.a.x and v.a.x <= h.b.x and h.a.y >= v.a.y and h.a.y <= v.b.y:
					var p = Vector2i(v.a.x,h.a.y)
					if p != d.a and p != d.b: return &"DOOR_INTERSECTION"
		if not supported: return &"UNSUPPORTED_DOOR"
		for j in range(i):
			var other = _doors[j]
			if other.has("circle_id"):continue
			if collinear(d,other) and low(d)<=high(other) and low(other)<=high(d): return &"DOOR_OVERLAP"
	var circle_keys: Dictionary={}
	for c in _circles:
		var key=[c.center,c.radius]
		if circle_keys.has(key):return &"DUPLICATE_CIRCLE"
		circle_keys[key]=true
		if c.id<=0 or ids.has(c.id) or c.id>=next_id:return &"INVALID_ID"
		ids[c.id]=true
		if c.radius<1 or c.radius!=floorf(c.radius) or not is_finite(c.radius) or c.segments<64 or c.segments>512 or c.segments%4!=0:return &"INVALID_CIRCLE"
		if not in_range(Vector2(c.center)-Vector2.ONE*c.radius) or not in_range(Vector2(c.center)+Vector2.ONE*c.radius):return &"OUT_OF_RANGE"
	for d in _doors:
		if not d.has("circle_id"):continue
		if d.id<=0 or ids.has(d.id) or d.id>=next_id:return &"INVALID_ID"
		ids[d.id]=true
		var c=get_circle(d.circle_id)
		if c.is_empty():return &"UNSUPPORTED_DOOR"
		if not is_finite(d.offset) or d.offset<0 or d.offset>=CircleBoundary.length(circle_points(c),true):return &"INVALID_APERTURE"
	var doors=get_doors()
	var segments=get_wall_segments()
	for i in range(doors.size()):
		var d=doors[i];var path=door_path(d)
		for k in range(path.size()-1):
			for w in segments:
				if w.id==d.get("circle_id",-1):continue
				if not d.has("circle_id") and StructureData.collinear(d,w):continue
				for point in SegmentGeometry.intersections(path[k],path[k+1],Vector2(w.a),Vector2(w.b)):
					if point.distance_to(path[0])>SegmentGeometry.EPS and point.distance_to(path[-1])>SegmentGeometry.EPS:return &"DOOR_INTERSECTION"
		for j in range(i):
			var other=door_path(doors[j])
			for k in range(path.size()-1):
				for l in range(other.size()-1):
					if not SegmentGeometry.intersections(path[k],path[k+1],other[l],other[l+1]).is_empty():return &"DOOR_OVERLAP"
	return &""
