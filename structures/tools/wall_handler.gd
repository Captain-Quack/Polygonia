@tool
extends ConstructionToolHandler
func _init() -> void:tool_id=&"wall"
func propose_edit(context: ConstructionContext,gesture: ConstructionGesture) -> ConstructionProposal:
	var result:=ConstructionProposal.new()
	var endpoint=preload("res://floors/tools/line_handler.gd").line_endpoint(gesture.start,gesture.end)
	result.command=StructureCommand.wall(gesture.start,endpoint,gesture.erase)
	result.expected_revision=context.model.structures.revision
	var evaluated=result.command.evaluate(context.model)
	result.reason=evaluated.reason;result.valid=result.reason==&""
	result.preview={"paths":[PackedVector2Array([Vector2(gesture.start)*context.cell_size,Vector2(endpoint)*context.cell_size])],"world_width":.1*context.cell_size,"closed":false,"label":"Wall" if result.valid else str(result.reason).replace("_"," "),"label_position":Vector2(endpoint)*context.cell_size}
	return result
