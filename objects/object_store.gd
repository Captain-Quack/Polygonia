class_name WorldObjectStore
extends RefCounted
signal changed
var _objects: Dictionary = {}
var _next_id := 1
func add(definition: WorldObjectDefinition, point: Vector2) -> PolygonWorldObject:
	if definition == null or not StructureData.in_range(point): return null
	var object = PolygonWorldObject.new(definition)
	object.id = _next_id
	_next_id += 1
	object.position = point
	_objects[object.id] = object
	changed.emit()
	return object
func get_object(id: int) -> PolygonWorldObject:
	return _objects.get(id)
func all() -> Array:
	return _objects.values()
func remove(id: int) -> bool:
	var object = get_object(id)
	if object == null: return false
	object.invalidate()
	_objects.erase(id)
	changed.emit()
	return true
func move(id: int, point: Vector2) -> bool:
	var object = get_object(id)
	if object == null or not StructureData.in_range(point): return false
	# Moving an object cancels in-progress use, but preserves finite stock.
	for provider in object.providers: provider.cancel_all()
	object.position = point
	object.revision += 1
	changed.emit()
	return true
func nearest(point: Vector2, distance: float = 0.6, kind: StringName = &"") -> PolygonWorldObject:
	var best: PolygonWorldObject
	for object in all():
		if kind != &"" and object.definition.definition_id != kind: continue
		var d = point.distance_to(object.position)
		if d < distance: distance = d; best = object
	return best
