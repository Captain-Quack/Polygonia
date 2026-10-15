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
	var circle_target=false
	var nearest: Dictionary={};var distance=INF;var ambiguous=false
	var tolerance=10.0/(context.cell_size*context.camera_scale)
	for r in records:
		var candidate=INF
		var shape=StructureData.door_path(r)
		for i in range(shape.size()-1):
			var projected=Geometry2D.get_closest_point_to_segment(pointer,shape[i],shape[i+1])
			candidate=minf(candidate,pointer.distance_to(projected))
		if candidate>tolerance:continue
		if candidate<distance-0.00001:
			nearest=r;distance=candidate;ambiguous=false
		elif absf(candidate-distance)<0.00001:ambiguous=true
	if not gesture.erase:
		for c in context.model.structures.get_circles():
			var projection=context.model.structures.project_circle(c,pointer)
			var candidate=projection.distance
			if candidate>tolerance:continue
			if candidate<distance-0.00001:
				nearest=c;distance=candidate;ambiguous=false;circle_target=true
			elif absf(candidate-distance)<0.00001:ambiguous=true
	var path:=PackedVector2Array()
	var a=pointer;var b=pointer
	if ambiguous:result.reason=&"AMBIGUOUS_WALL"
	elif not nearest.is_empty():
		if gesture.erase:
			a=Vector2(nearest.a);b=Vector2(nearest.b)
			path=StructureData.door_path(nearest)
			result.command=StructureCommand.remove_door(nearest.id)
		elif circle_target:
			var points=context.model.structures.circle_points(nearest)
			var projection=context.model.structures.project_circle(nearest,pointer)
			# Local quarter-cell spacing along the boundary, independent of zoom.
			var center=roundf(projection.offset*4.0)*.25
			var start=fposmod(center-.5,CircleBoundary.length(points,true))
			result.command=StructureCommand.circle_door(nearest.id,start)
			path=CircleBoundary.slice(points,start,1.0)
			a=path[0];b=path[-1]
		else:
			var horizontal=nearest.a.y==nearest.b.y
			var coordinate=pointer.x if horizontal else pointer.y
			# Nearest integer start to projection minus half a cell; ties toward -infinity.
			var start=int(ceil(coordinate-1.0))
			a=Vector2(start,nearest.a.y) if horizontal else Vector2(nearest.a.x,start)
			b=a+(Vector2.RIGHT if horizontal else Vector2.DOWN)
			result.command=StructureCommand.place_door(StructureData.coordinate(a),StructureData.coordinate(b))
		var evaluated=result.command.evaluate(context.model)
		result.reason=evaluated.reason;result.valid=result.reason==&""
	if path.is_empty():path=PackedVector2Array([a,b])
	for i in range(path.size()):path[i]*=context.cell_size
	result.preview={"paths":[path],"markers":PackedVector2Array([a*context.cell_size,b*context.cell_size]),"world_width":.1*context.cell_size,"closed":false,"label":("Remove door" if gesture.erase else "Door · 1 cell") if result.valid else str(result.reason).replace("_"," "),"label_position":b*context.cell_size}
	return result
