class_name AgentMotion
extends RefCounted
## Presentation samples of the last simulation step; never changes world state.
## Retaining each traveled segment avoids interpolation through wall corners.
var _points := PackedVector2Array()
var _length := 0.0
var _from_facing := 0.0
var _to_facing := 0.0
func begin(position: Vector2,facing: float) -> void:
	_points = PackedVector2Array([position])
	_length = 0.0
	_from_facing = facing; _to_facing = facing
func record(position: Vector2,facing: float) -> void:
	if _points.is_empty(): begin(position,facing); return
	var distance = _points[-1].distance_to(position)
	if distance > 0:
		_points.append(position); _length += distance
	_to_facing = facing
func sample(alpha: float) -> Dictionary:
	alpha = clampf(alpha,0,1)
	var position = _points[0] if not _points.is_empty() else Vector2.ZERO
	var remaining = _length * alpha
	for i in range(1,_points.size()):
		var distance = _points[i-1].distance_to(_points[i])
		if remaining <= distance:
			position = _points[i-1].lerp(_points[i],remaining/distance)
			break
		remaining -= distance; position = _points[i]
	return {"position":position,"facing":lerp_angle(_from_facing,_to_facing,alpha)}
