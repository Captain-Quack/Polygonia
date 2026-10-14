@tool
class_name ConstructionCircleHandler
extends ConstructionToolHandler
## Center/radius snap; the circumference remains smooth between grid points.
const Geometry = preload("res://floors/shape_geometry.gd")
@export_range(0.001, 0.25, 0.001) var target_chord_error_cells := 0.02
@export_range(64, 512, 4) var max_segments := 256

func _init() -> void:
	tool_id = &"circle"

static func snapped_radius(center: Vector2i, endpoint: Vector2i, step: int) -> float:
	var spacing := maxi(step, 1)
	return roundf(Vector2(endpoint - center).length() / spacing) * spacing

func circle_polygon(center: Vector2i, endpoint: Vector2i, step: int) -> PackedVector2Array:
	var radius := snapped_radius(center, endpoint, step)
	if radius <= 0:
		return PackedVector2Array()
	# Sagitta determines chord error. Cap complexity and align cardinal samples.
	var angle := acos(clampf(1.0 - maxf(target_chord_error_cells, 0.001) / radius, -1.0, 1.0))
	var segments := clampi(int(ceil(PI / maxf(angle, 0.00001) / 4.0)) * 4, 64, maxi(64, max_segments / 4 * 4))
	var points := PackedVector2Array()
	for i in range(segments):
		var offset := Vector2.from_angle(TAU * i / segments) * radius
		# Exact cardinal extents make tangencies with grid-aligned shapes stable.
		if i == 0:
			offset = Vector2(radius, 0)
		elif i == segments / 4:
			offset = Vector2(0, radius)
		elif i == segments / 2:
			offset = Vector2(-radius, 0)
		elif i == segments * 3 / 4:
			offset = Vector2(0, -radius)
		points.append(Vector2(center) + offset)
	return points

func commit(data, a: Vector2i, b: Vector2i, step: int, erase: bool) -> void:
	var polygon := circle_polygon(a, b, step)
	if not polygon.is_empty():
		data.apply_polygon(polygon, erase)

func preview_geometry(a: Vector2i, b: Vector2i, step: int, cell_size: float, _radius: float) -> Dictionary:
	var polygon := circle_polygon(a, b, step)
	var center := Vector2(a) * cell_size
	var radius := snapped_radius(a, b, step)
	if polygon.is_empty():
		return {"paths": [], "fills": [], "closed": true, "markers": PackedVector2Array([center])}
	for i in range(polygon.size()):
		polygon[i] *= cell_size
	var direction := Vector2(b - a).normalized()
	var edge := center + direction * radius * cell_size
	return {"paths": [polygon], "fills": [polygon], "closed": true,
		"guides": [PackedVector2Array([center, edge])],
		"markers": PackedVector2Array([center, polygon[0], polygon[polygon.size() / 4], polygon[polygon.size() / 2], polygon[polygon.size() * 3 / 4]]),
		"label": "Radius: %s cells  ·  Diameter: %s" % [radius, radius * 2], "label_position": edge}
