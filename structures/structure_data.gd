class_name StructureData
extends RefCounted
## Sparse authoritative records. Public accessors return independent value copies.
const LIMIT := 1000000
var _walls: Array = []
var _doors: Array = []
var next_id := 1
var revision := 0
var topology_revision := 0
var barrier_revision := 0
var traversal_revision := 0
func get_walls() -> Array: return _walls.duplicate(true)
func get_doors() -> Array: return _doors.duplicate(true)
func get_door(id: int) -> Dictionary:
	for door in _doors:
		if door.id == id: return door.duplicate(true)
	return {}
func copy() -> StructureData:
	var result := StructureData.new()
	result._walls = get_walls()
	result._doors = get_doors()
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
		if not valid_segment(r.a,r.b) or r.a != canonical(r.a,r.b)[0]: return &"INVALID_SEGMENT"
		if r.id <= 0 or ids.has(r.id) or r.id >= next_id: return &"INVALID_ID"
		ids[r.id] = true
	for r in _walls:
		if r.material != &"solid": return &"INVALID_MATERIAL"
	for i in range(_doors.size()):
		var d = _doors[i]
		if d.state not in [&"OPEN",&"CLOSED"] or (d.state == &"OPEN" and d.locked): return &"INVALID_STATE"
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
			if collinear(d,other) and low(d)<=high(other) and low(other)<=high(d): return &"DOOR_OVERLAP"
	return &""
