@tool
class_name ConstructionLineHandler
extends ConstructionToolHandler

func _init() -> void:
	tool_id = &"line"

static func line_endpoint(a: Vector2i, b: Vector2i) -> Vector2i:
	var difference := b - a
	return Vector2i(b.x, a.y) if absi(difference.x) >= absi(difference.y) else Vector2i(a.x, b.y)

func commit(data, a: Vector2i, b: Vector2i, _step: int, erase: bool) -> void:
	data.apply_line(a, line_endpoint(a, b), erase)

func preview_geometry(a: Vector2i, b: Vector2i, _step: int, cell_size: float, _radius: float) -> Dictionary:
	return {"paths": [PackedVector2Array([Vector2(a) * cell_size, Vector2(line_endpoint(a, b)) * cell_size])], "fills": [], "closed": false, "use_line_width": true}
