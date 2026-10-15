@tool
extends ConstructionToolHandler
func _init() -> void:tool_id=&"door"
func snap_policy() -> StringName:return &"host_base_grid"
func propose_edit(context: ConstructionContext,gesture: ConstructionGesture) -> ConstructionProposal:
	var result:=ConstructionProposal.new()
	result.valid=false;result.reason=&"POINT_AT_A_WALL"
	result.expected_revision=context.model.structures.revision
	var pointer=gesture.raw_end
	var records=context.model.structures.get_doors() if gesture.erase else context.model.structures.get_walls()
	var nearest: Dictionary={};var distance=INF;var ambiguous=false
	var tolerance=10.0/(context.cell_size*context.camera_scale)
	for r in records:
		var projected=Geometry2D.get_closest_point_to_segment(pointer,Vector2(r.a),Vector2(r.b))
		var candidate=pointer.distance_to(projected)
		if candidate>tolerance:continue
		if candidate<distance-0.00001:
			nearest=r;distance=candidate;ambiguous=false
		elif absf(candidate-distance)<0.00001:ambiguous=true
	var a=pointer;var b=pointer
	if ambiguous:result.reason=&"AMBIGUOUS_WALL"
	elif not nearest.is_empty():
		if gesture.erase:
			a=Vector2(nearest.a);b=Vector2(nearest.b)
			result.command=StructureCommand.remove_door(nearest.id)
		else:
			var horizontal=nearest.a.y==nearest.b.y
			var coordinate=pointer.x if horizontal else pointer.y
			# Nearest integer start to projection minus half a cell; ties toward -infinity.
			var start=int(ceil(coordinate-1.0))
			a=Vector2(start,nearest.a.y) if horizontal else Vector2(nearest.a.x,start)
			b=a+(Vector2.RIGHT if horizontal else Vector2.DOWN)
			result.command=StructureCommand.place_door(Vector2i(a),Vector2i(b))
		var evaluated=result.command.evaluate(context.model)
		result.reason=evaluated.reason;result.valid=result.reason==&""
	result.preview={"paths":[PackedVector2Array([a*context.cell_size,b*context.cell_size])],"markers":PackedVector2Array([a*context.cell_size,b*context.cell_size]),"world_width":.1*context.cell_size,"closed":false,"label":("Remove door" if gesture.erase else "Door · 1 cell") if result.valid else str(result.reason).replace("_"," "),"label_position":b*context.cell_size}
	return result
