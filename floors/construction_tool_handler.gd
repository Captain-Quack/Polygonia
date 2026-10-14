@tool
class_name ConstructionToolHandler
extends Resource
## Override commit and preview_geometry; register by matching the definition's ID.
@export var tool_id: StringName = &""

func commit(_data, _a: Vector2i, _b: Vector2i, _step: int, _erase: bool) -> void:
	pass

## Return paths, fills, closed, and use_line_width. Coordinates are world pixels.
func preview_geometry(_a: Vector2i, _b: Vector2i, _step: int, _cell_size: float, _radius: float) -> Dictionary:
	return {"paths": [], "fills": [], "closed": false, "use_line_width": false}
