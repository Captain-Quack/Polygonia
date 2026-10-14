@tool
class_name ConstructionSquareHandler
extends ConstructionToolHandler
const Geometry = preload("res://floors/shape_geometry.gd")

func _init() -> void:
	tool_id = &"square"

static func shape(a: Vector2i, b: Vector2i, step: int) -> Rect2i:
	return Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), Vector2i(maxi(absi(b.x - a.x), step), maxi(absi(b.y - a.y), step)))

func commit(data, a: Vector2i, b: Vector2i, step: int, erase: bool) -> void:
	data.apply_rect(shape(a, b, step), erase)

func preview_geometry(a: Vector2i, b: Vector2i, step: int, cell_size: float, radius: float) -> Dictionary:
	var cells := shape(a, b, step)
	var rect := Rect2(Vector2(cells.position) * cell_size, Vector2(cells.size) * cell_size)
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var rounded := Geometry.rounded_loop(points, radius)
	return {"paths": [rounded], "fills": [rounded], "closed": true, "use_line_width": false}
