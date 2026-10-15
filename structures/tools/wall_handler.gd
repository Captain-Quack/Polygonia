@tool
extends ConstructionToolHandler
func _init() -> void:tool_id=&"wall"
func propose_edit(context: ConstructionContext,gesture: ConstructionGesture) -> ConstructionProposal:
	var result:=ConstructionProposal.new()
	var candidates=StructureSnap.targets(context)
	var start=StructureSnap.nearest(context,gesture.raw_start,Vector2(gesture.start),candidates)
	var delta=Vector2(gesture.end)-start
	var horizontal=absf(delta.x)>=absf(delta.y)
	var endpoint=Vector2(gesture.end.x,start.y) if horizontal else Vector2(start.x,gesture.end.y)
	endpoint=StructureSnap.nearest(context,gesture.raw_end,endpoint,candidates,1 if horizontal else 0,start.y if horizontal else start.x)
	if horizontal:start.y=endpoint.y
	else:start.x=endpoint.x
	result.command=StructureCommand.wall(StructureData.coordinate(start),StructureData.coordinate(endpoint),gesture.erase)
	result.expected_revision=context.model.structures.revision
	var evaluated=result.command.evaluate(context.model)
	result.reason=evaluated.reason;result.valid=result.reason==&""
	result.preview={"paths":[PackedVector2Array([start*context.cell_size,endpoint*context.cell_size])],"world_width":.1*context.cell_size,"closed":false,"label":"Wall" if result.valid else str(result.reason).replace("_"," "),"label_position":endpoint*context.cell_size,"markers":PackedVector2Array([start*context.cell_size,endpoint*context.cell_size])}
	return result
