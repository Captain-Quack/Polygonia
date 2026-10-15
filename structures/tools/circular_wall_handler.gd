@tool
extends ConstructionCircleHandler
func _init() -> void:tool_id=&"circular_wall"
func propose_edit(context: ConstructionContext,gesture: ConstructionGesture) -> ConstructionProposal:
	var result:=ConstructionProposal.new()
	var points=circle_polygon(gesture.start,gesture.end,gesture.step)
	var radius=snapped_radius(gesture.start,gesture.end,gesture.step)
	result.command=StructureCommand.circle(gesture.start,radius,points.size(),gesture.erase)
	result.expected_revision=context.model.structures.revision
	var evaluated=result.command.evaluate(context.model)
	result.reason=evaluated.reason;result.valid=result.reason==&""
	result.preview=preview_geometry(gesture.start,gesture.end,gesture.step,context.cell_size,context.corner_radius_world)
	result.preview.fills=[];result.preview.world_width=.1*context.cell_size
	if not result.valid:result.preview.label=str(result.reason).replace("_"," ")
	else:result.preview.label=("Remove circular wall" if gesture.erase else "Circular wall")+" · Radius: %s cells"%radius
	return result
