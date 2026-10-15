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

## New handlers can inspect world state; legacy handlers retain their existing API.
func instructions() -> String:
	return "Left-drag: paint · Right-drag: erase · Esc: cancel"

func control_point_count() -> int:
	return 2

func snap_policy() -> StringName:
	return &"visible_grid"

func propose_edit(context: ConstructionContext, gesture: ConstructionGesture) -> ConstructionProposal:
	var result := ConstructionProposal.new()
	result.preview = preview_geometry(gesture.start, gesture.end, gesture.step, context.cell_size, context.corner_radius_world)
	var command = preload("res://construction/legacy_floor_command.gd").new()
	command.handler = self
	command.gesture = gesture
	result.command = command
	return result
