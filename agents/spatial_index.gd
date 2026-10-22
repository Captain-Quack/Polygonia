class_name AgentSpatialIndex
extends RefCounted
## Broad phase only. Callers still perform visibility/contact checks.
const CELL_SIZE := 6.0
var _buckets: Dictionary = {}
var _ordered: Array = []
func rebuild(items: Array) -> void:
	_buckets.clear(); _ordered=items.duplicate()
	_ordered.sort_custom(func(a,b): return a.id<b.id)
	for item in _ordered:
		var c=Vector2i((item.position/CELL_SIZE).floor())
		if not _buckets.has(c): _buckets[c]=[]
		_buckets[c].append(item)
func query(point: Vector2,radius: float) -> Array:
	if not point.is_finite() or not is_finite(radius) or radius<0: return []
	var lo=Vector2i(((point-Vector2.ONE*radius)/CELL_SIZE).floor())
	var hi=Vector2i(((point+Vector2.ONE*radius)/CELL_SIZE).floor())
	# Large radii traverse occupied data instead of millions of empty cells.
	if float(hi.x-lo.x+1)*float(hi.y-lo.y+1)>maxi(16,_buckets.size()*2):
		return _ordered.filter(func(item): return item.position.distance_squared_to(point)<=radius*radius)
	var result: Array=[]
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			for item in _buckets.get(Vector2i(x,y),[]):
				if item.position.distance_squared_to(point)<=radius*radius: result.append(item)
	result.sort_custom(func(a,b): return a.id<b.id)
	return result
