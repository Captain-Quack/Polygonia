@tool
extends ConstructionCircleHandler
func _init() -> void:tool_id=&"arc_wall"
func instructions() -> String:
	return "Arc: center → start → end · Shift: other way · Right-click: erase · Esc: cancel"
func control_point_count() -> int:return 3
func endpoint_projection(context: ConstructionContext,points: PackedVector2Array,raw: Vector2,snapped: Vector2) -> Dictionary:
	var result=CircleBoundary.project(points,snapped)
	var tolerance=10.0/(context.cell_size*context.camera_scale)
	var nearest=tolerance
	# Floor contours include the exact junctions of circles and rectangles.
	for ring in context.model.floors.boundary_loops():
		for point in ring:
			var projected=CircleBoundary.project(points,Vector2(point))
			var distance=raw.distance_to(Vector2(point))
			if projected.distance<.0005 and distance<nearest:
				nearest=distance;result=projected
	for wall in context.model.structures.get_walls():
		for i in range(points.size()):
			for point in SegmentGeometry.intersections(points[i],points[(i+1)%points.size()],Vector2(wall.a),Vector2(wall.b)):
				var distance=raw.distance_to(point)
				if distance<nearest:nearest=distance;result=CircleBoundary.project(points,point)
	return result
func propose_edit(context: ConstructionContext,gesture: ConstructionGesture) -> ConstructionProposal:
	var result:=ConstructionProposal.new();result.valid=false;result.reason=&"CHOOSE_RADIUS"
	var controls=gesture.control_points
	var center=gesture.start if controls.is_empty() else Vector2i(controls[0])
	var radial=gesture.end if controls.size()<2 else Vector2i(controls[1])
	var points=circle_polygon(center,radial,gesture.step)
	var radius=snapped_radius(center,radial,gesture.step)
	# Reuse the host's sampling when adding/removing another part of it.
	for c in context.model.structures.get_circles():
		if c.center==center and c.radius==radius:points=context.model.structures.circle_points(c);break
	var path=points;var total=CircleBoundary.length(points,true) if not points.is_empty() else 0.0
	var start_offset=0.0;var width=total;var finish=Vector2(radial)
	var label="Arc · click radius/start"
	if controls.size()>=3 and points.size()>2:
		var start_raw=Vector2(radial) if gesture.raw_points.size()<2 else Vector2(gesture.raw_points[1])
		var first=endpoint_projection(context,points,start_raw,Vector2(radial))
		var last=endpoint_projection(context,points,gesture.raw_end,Vector2(controls[2]))
		start_offset=first.offset;finish=last.point
		width=fposmod(last.offset-first.offset,total)
		if first.point.distance_to(last.point)<.0001:width=total
		elif gesture.alternate:start_offset=last.offset;width=total-width
		path=CircleBoundary.slice(points,start_offset,width)
		result.command=StructureCommand.arc(center,radius,points.size(),start_offset,width,gesture.erase)
		var evaluated=result.command.evaluate(context.model)
		result.reason=evaluated.reason;result.valid=result.reason==&""
		label=("Erase arc" if gesture.erase else "Arc")+" · %.1f° · click end · Shift: other sweep"%(width/total*360.0)
		if not result.valid:label=str(result.reason).replace("_"," ")
	var pixels:=PackedVector2Array()
	for p in path:pixels.append(p*context.cell_size)
	var guides: Array=[];var markers:=PackedVector2Array([Vector2(center)*context.cell_size])
	if not pixels.is_empty():
		guides.append(PackedVector2Array([Vector2(center)*context.cell_size,pixels[0]]))
		markers.append(pixels[0])
		if controls.size()>=3:
			guides.append(PackedVector2Array([Vector2(center)*context.cell_size,pixels[-1]]));markers.append(pixels[-1])
	result.expected_revision=context.model.structures.revision
	result.preview={"paths":[pixels] if pixels.size()>1 else [],"closed":controls.size()<3,"fills":[],"guides":guides,"markers":markers,"world_width":.1*context.cell_size,"label":label,"label_position":finish*context.cell_size,"pending":controls.size()<3}
	return result
