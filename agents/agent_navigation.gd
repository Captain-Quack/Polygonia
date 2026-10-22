class_name AgentNavigation
extends RefCounted
## Geometry-aware bounded A*. Resource beliefs never enter this service.
const STEP := 0.5
const MAX_EXPANSIONS := 4096
const MARGIN := 12.0
const DIRECTIONS := [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]
var model: WorldModel
var _revision := -1
var _radius := -1.0
var _barriers: Array = []
var _route_cache: Dictionary = {}
var _time := 0.0
var _remaining := -1
var expansions_this_tick := 0
var cache_hits_this_tick := 0
var deferred_this_tick := 0
func begin_tick(now: float,expansion_budget: int = 8192) -> void:
	_time=now; _remaining=maxi(0,expansion_budget)
	expansions_this_tick=0; cache_hits_this_tick=0; deferred_this_tick=0
func _init(world: WorldModel = null) -> void:
	model = world
func _prepare(radius: float) -> void:
	if _revision == model.structures.traversal_revision and _radius == radius: return
	_revision = model.structures.traversal_revision; _radius = radius
	_route_cache.clear()
	_barriers = []
	var openable: Dictionary = {}
	for door in model.structures.get_doors():
		if model.physical.crossing_option(door.id,{"radius":radius,"can_open_doors":true}).kind != &"BLOCKED":
			openable[door.id] = true
	for segment in model.physical.segments():
		if segment.door and openable.has(segment.id): continue
		_barriers.append(segment)
func clear_segment(from: Vector2,to: Vector2,radius: float) -> bool:
	_prepare(radius)
	for s in _barriers:
		if not PhysicalQueries.bounds_overlap(from,to,s.a,s.b,radius + PhysicalQueries.WALL_RADIUS): continue
		if is_finite(PhysicalQueries.capsule_time(from,to,s.a,s.b,radius + PhysicalQueries.WALL_RADIUS)): return false
	return true
func route(from: Vector2,to: Vector2,radius: float) -> Dictionary:
	if not StructureData.in_range(from) or not StructureData.in_range(to) or not is_finite(radius) or radius < 0:
		return {"status":&"INVALID","points":[]}
	_prepare(radius)
	var key=Vector4(from.x,from.y,to.x,to.y)
	var cached: Dictionary=_route_cache.get(key,{})
	if not cached.is_empty() and _time-float(cached.at)<2.0:
		cache_hits_this_tick+=1
		return cached.result.duplicate(true)
	var result=_search_route(from,to,radius)
	if result.status==&"DEFERRED": deferred_this_tick+=1
	else:
		if _route_cache.size()>=256 and not _route_cache.has(key):
			for oldest in _route_cache: _route_cache.erase(oldest); break
		_route_cache[key]={"at":_time,"result":result.duplicate(true)}
	return result
func _search_route(from: Vector2,to: Vector2,radius: float) -> Dictionary:
	if clear_segment(from,to,radius): return {"status":&"OK","points":[to]}
	if not clear_segment(from,from,radius) or not clear_segment(to,to,radius):
		return {"status":&"BLOCKED","points":[]}
	if _remaining==0: return {"status":&"DEFERRED","points":[]}
	var bounds = Rect2(from,Vector2.ZERO).expand(to).grow(MARGIN)
	var heap: Array = []
	var costs: Dictionary = {}
	var parent: Dictionary = {}
	var closed: Dictionary = {}
	var origin = Vector2i((from / STEP).round())
	for dx in range(-1,2):
		for dy in range(-1,2):
			var cell = origin + Vector2i(dx,dy)
			var p = Vector2(cell) * STEP
			if clear_segment(from,p,radius):
				costs[cell] = from.distance_to(p)
				_push(heap,[costs[cell] + p.distance_to(to),cell])
	var expanded := 0
	while not heap.is_empty() and expanded < MAX_EXPANSIONS and _remaining!=0:
		var cell: Vector2i = _pop(heap)[1]
		if closed.has(cell): continue
		closed[cell] = true; expanded += 1
		expansions_this_tick+=1
		if _remaining>0: _remaining-=1
		var p = Vector2(cell) * STEP
		if p.distance_to(to) <= STEP * 1.5 and clear_segment(p,to,radius):
			var points: Array = [to,p]
			while parent.has(cell):
				cell = parent[cell]; points.append(Vector2(cell) * STEP)
			points.reverse()
			return {"status":&"OK","points":points}
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if closed.has(next): continue
			var q = Vector2(next) * STEP
			if not bounds.has_point(q) or not StructureData.in_range(q): continue
			var cost: float = costs[cell] + p.distance_to(q)
			if cost >= float(costs.get(next,INF)) or not clear_segment(p,q,radius): continue
			costs[next] = cost; parent[next] = cell
			_push(heap,[cost + q.distance_to(to),next])
	# Either work limit leaves an unfinished search uncertain, never disproven.
	return {"status":&"DEFERRED" if not heap.is_empty() else &"NO_ROUTE","points":[]}
func prepare_step(from: Vector2,to: Vector2,radius: float,actor: int) -> bool:
	# Open only doors actually reached, never every door on the planned route.
	for hit in model.physical._hits(from,to,radius):
		var option = model.physical.crossing_option(hit.entity_id,{"radius":radius,"can_open_doors":true})
		if option.kind != &"OPEN_THEN_PASS": return false
		if not model.execute(StructureCommand.door_action(hit.entity_id,&"OPEN",actor)).accepted: return false
	var sweep = model.physical.sweep(from,to,radius)
	return sweep.valid and not sweep.hit
static func _push(heap: Array,item: Array) -> void:
	heap.append(item)
	var i = heap.size() - 1
	while i > 0:
		var parent_index = (i - 1) / 2
		if heap[parent_index][0] <= item[0]: break
		heap[i] = heap[parent_index]; i = parent_index
	heap[i] = item
static func _pop(heap: Array) -> Array:
	var result: Array = heap[0]
	var last = heap.pop_back()
	if heap.is_empty(): return result
	var i := 0
	while i * 2 + 1 < heap.size():
		var child = i * 2 + 1
		if child + 1 < heap.size() and heap[child+1][0] < heap[child][0]: child += 1
		if last[0] <= heap[child][0]: break
		heap[i] = heap[child]; i = child
	heap[i] = last
	return result

