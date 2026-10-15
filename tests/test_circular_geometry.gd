extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func circle(model,center: Vector2i=Vector2i.ZERO,radius: int=5):
	var result=model.execute(StructureCommand.circle(center,radius,64))
	check(result.accepted,"circle primitive accepted")
	return model.structures.get_circles()[-1].id
func _initialize() -> void:
	var model=WorldModel.new()
	var host=circle(model)
	var revision=model.structures.revision
	model.execute(StructureCommand.circle(Vector2i.ZERO,5,64))
	check(model.structures.revision==revision,"circle repaint is a no-op")
	circle(model,Vector2i.ZERO,2)
	check(model.regions.get_regions().size()==3,"nested circles form two bounded spaces")
	var area=0.0
	for r in model.regions.get_regions():
		if r.bounded:area+=r.area
	check(absf(area-PI*25)<.2,"nested circular areas exclude holes")
	var inner_circle=model.structures.get_circles()[-1].id
	var inner_door=model.execute(StructureCommand.circle_door(inner_circle,0.0))
	check(inner_door.accepted,"inner circular door fits nested rooms")
	var nested_portal=model.regions.get_portals()[0]
	check(nested_portal.region_a>0 and nested_portal.region_b>0 and nested_portal.region_a!=nested_portal.region_b,"nested curved portal joins two bounded regions")
	model.execute(StructureCommand.remove_door(nested_portal.id))
	var change=model.execute(StructureCommand.circle(Vector2i.ZERO,2,64,true))
	check(absf(model.regions.region(model.regions.locate(Vector2.ZERO).region_id).area-PI*25)<.2,"removing inner circle merges its room into surrounding space")
	check(StructureCommand.restore(model,change,true).accepted,"circle removal undo")
	check(StructureCommand.restore(model,change,false).accepted,"circle removal redo")
	model.execute(StructureCommand.wall(Vector2i(-6,0),Vector2i(6,0),false))
	check(model.regions.get_regions().size()==3,"straight wall crossing circle divides it")
	check(model.regions.locate(Vector2(0,1)).region_id!=model.regions.locate(Vector2(0,-1)).region_id,"circle halves distinct")
	var incidents=model.regions.locate(Vector2(5,0)).incident_region_ids
	check(incidents.size()==3,"straight/circle junction incidence")
	model.free()
	model=WorldModel.new();host=circle(model)
	var points=model.structures.circle_points(model.structures.get_circle(host))
	var perimeter=CircleBoundary.length(points,true)
	for center in [0.0,perimeter*.125,perimeter*.25,perimeter*.51,perimeter-.1]:
		var offset=fposmod(center-.5,perimeter)
		var placed=model.execute(StructureCommand.circle_door(host,offset))
		check(placed.accepted,"door at seam or oblique angle")
		if not placed.accepted:continue
		var d=model.structures.get_doors()[0]
		check(absf(CircleBoundary.length(d.path)-1)<.00001,"curved aperture one cell along boundary")
		var middle=CircleBoundary.middle(d.path);var normal=Vector2(-middle.direction.y,middle.direction.x)
		check(model.physical.sweep(middle.point-normal,middle.point+normal,.2).hit,"curved leaf collision")
		check(model.physical.crossing_option(d.id,{"radius":.2,"can_open_doors":true}).kind==&"OPEN_THEN_PASS","capable agent can open curved door")
		var before=model.regions.rebuild_count
		model.execute(StructureCommand.door_action(d.id,&"OPEN"))
		check(not model.physical.sweep(middle.point-normal,middle.point+normal,.2).hit,"oblique open door clearance")
		check(model.physical.visibility_hits(middle.point-normal,middle.point+normal).is_empty(),"oblique open door sight")
		check(model.regions.rebuild_count==before,"door state avoids room rebuild")
		model.occupancy_query=func(capsule):
			check(capsule.has("path") and capsule.path.size()>2,"occupancy receives curved path")
			check(capsule.a==capsule.path[0] and capsule.b==capsule.path[-1],"occupancy endpoints match curved aperture")
			return true
		check(not model.execute(StructureCommand.door_action(d.id,&"CLOSE")).accepted,"occupied curved door stays open")
		model.occupancy_query=Callable()
		model.execute(StructureCommand.door_action(d.id,&"CLOSE"));model.execute(StructureCommand.door_action(d.id,&"LOCK"))
		check(not model.execute(StructureCommand.door_action(d.id,&"OPEN")).accepted,"curved lock blocks opening")
		var payload=StructureCodec.encode(model.structures)
		check(payload.version==2 and StructureCodec.decode(payload).valid,"v2 curved door roundtrip")
		var bad=payload.duplicate(true);bad.doors[0].circle_id=999
		check(not StructureCodec.decode(bad).valid,"missing circle host rejected")
		model.execute(StructureCommand.remove_door(d.id))
	check(model.structures.get_circles().size()==1,"door erasure preserves circle")
	var duplicate=StructureCodec.encode(model.structures)
	duplicate.circles.append(duplicate.circles[0].duplicate(true));duplicate.circles[-1].id=duplicate.next_id;duplicate.next_id+=1
	check(not StructureCodec.decode(duplicate).valid,"duplicate circle geometry rejected")
	var door_change=model.execute(StructureCommand.circle_door(host,perimeter-.5))
	check(door_change.accepted,"door on seam for stale support")
	var rev=model.structures.revision
	check(not model.execute(StructureCommand.wall(Vector2i(4,0),Vector2i(6,0),false)).accepted,"wall crossing curved aperture rejected")
	check(model.structures.revision==rev,"crossing edit rejected atomically")
	var removal=model.execute(StructureCommand.circle(Vector2i.ZERO,5,64,true))
	check(model.structures.get_circles().is_empty() and model.structures.get_doors().is_empty(),"circle erase removes supported doors")
	check(StructureCommand.restore(model,removal,true).accepted and model.structures.get_doors().size()==1,"undo restores circle and curved doors")
	model.free()
	model=WorldModel.new();circle(model);circle(model,Vector2i(5,0))
	check(model.regions.get_regions().size()==4,"overlapping circles form three bounded regions")
	model.free()
	# Sampling at larger radii and translated centers must not leave wall
	# fragments in an open aperture because of rounded path interpolation.
	for fixture in [[Vector2i(1000,1000),100,160],[Vector2i.ZERO,1000,256]]:
		model=WorldModel.new()
		model.execute(StructureCommand.circle(fixture[0],fixture[1],fixture[2]))
		host=model.structures.get_circles()[0].id
		points=model.structures.circle_points(model.structures.get_circle(host))
		var placed=model.execute(StructureCommand.circle_door(host,CircleBoundary.length(points,true)/8-.5))
		check(placed.accepted,"large translated circle door valid")
		var d=model.structures.get_doors()[0];var middle=CircleBoundary.middle(d.path)
		var normal=Vector2(-middle.direction.y,middle.direction.x)
		model.execute(StructureCommand.door_action(d.id,&"OPEN"))
		check(not model.physical.sweep(middle.point-normal,middle.point+normal,.2).hit,"large translated curved opening clears movement")
		check(model.physical.crossing_option(d.id,{"radius":.2}).kind==&"PASS","large translated curved opening is traversable")
		model.free()
	for fixture in [[Vector2i(100000,100000),5],[Vector2i(10000,10000),20],[Vector2i.ZERO,5],[Vector2i.ZERO,100],[Vector2i(10000,10000),100]]:
		model=WorldModel.new()
		if fixture[1]==100:
			model.execute(StructureCommand.circle(fixture[0],fixture[1],160));host=model.structures.get_circles()[0].id
		else:host=circle(model,fixture[0],fixture[1])
		var expected_id=model.regions.locate(Vector2(fixture[0])).region_id
		check(expected_id>0,"translated circular center remains enclosed")
		if expected_id>0:check(model.regions.region(expected_id).area>fixture[1]*fixture[1]*3.0,"circle does not become its own hole")
		points=model.structures.circle_points(model.structures.get_circle(host))
		var total=CircleBoundary.length(points,true)
		for i in range(8):
			var placed=model.execute(StructureCommand.circle_door(host,fposmod(total*i/8-.5,total)))
			check(placed.accepted,"translated portal placement")
			if not placed.accepted:continue
			var portal=model.regions.get_portals()[0]
			check(portal.region_a!=portal.region_b and (portal.region_a==expected_id or portal.region_b==expected_id),"curved portal connects enclosed region to exterior")
			check(model.regions.locate(Vector2(fixture[0])).region_id==expected_id,"curved aperture preserves region identity at translated coordinates")
			model.execute(StructureCommand.remove_door(portal.id))
		model.free()
	print("circular_geometry: %d failures"%failures);quit(1 if failures else 0)
