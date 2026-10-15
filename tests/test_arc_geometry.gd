extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	var C=load("res://structures/structure_command.gd")
	check(C.new().has_method("arc"),"structure commands can create partial arcs")
	if not C.new().has_method("arc"):quit(1);return
	var model=WorldModel.new()
	var full=CircleBoundary.points(Vector2.ZERO,5,64)
	var total=CircleBoundary.length(full,true)
	var half=total*.5
	check(model.execute(C.arc(Vector2i.ZERO,5,64,0.0,half)).accepted,"paint lower semicircle")
	check(model.regions.get_regions().size()==1,"open semicircle creates no room")
	check(not model.physical.sweep(Vector2.ZERO,Vector2(0,-6),.2).hit,"missing upper arc remains traversable")
	check(model.physical.sweep(Vector2.ZERO,Vector2(0,6),.2).hit,"painted lower arc blocks")
	model.execute(C.wall(Vector2i(-5,0),Vector2i(5,0),false))
	var room=model.regions.locate(Vector2(0,1)).region_id
	check(room>0 and model.regions.locate(Vector2(0,-1)).region_id==0,"straight diameter closes only semicircular room")
	check(absf(model.regions.region(room).area-PI*12.5)<.1,"semicircle area")
	var host=model.structures.get_circles()[0].id
	check(not model.execute(C.circle_door(host,total-.5)).accepted,"door cannot straddle unbuilt arc endpoint")
	var door=model.execute(C.circle_door(host,half*.5-.5))
	check(door.accepted,"same curved door command fits arc")
	var id=model.structures.get_doors()[0].id
	model.execute(C.door_action(id,&"OPEN"))
	check(not model.physical.sweep(Vector2(0,4),Vector2(0,6),.2).hit,"arc doorway opens")
	var rev=model.structures.revision
	check(not model.execute(C.arc(Vector2i.ZERO,5,64,half*.5,.1,true)).accepted,"partial door support erase rejects")
	check(model.structures.revision==rev,"rejected arc edit atomic")
	var removed=model.execute(C.arc(Vector2i.ZERO,5,64,half*.5-.5,1.0,true))
	check(removed.accepted and model.structures.get_doors().is_empty(),"erasing full aperture removes its door")
	check(model.regions.locate(Vector2(0,1)).region_id==0,"gap opens room to exterior")
	check(C.restore(model,removed,true).accepted and model.structures.get_doors().size()==1,"arc erase undo restores geometry and door")
	model.execute(C.remove_door(id))
	model.execute(C.arc(Vector2i.ZERO,5,64,half,half))
	check(model.structures.get_circles().size()==1 and model.structures.get_circles()[0].id==host,"complementary arc retains compact host identity")
	check(model.regions.get_regions().size()==3,"full circle and diameter form two rooms")
	var payload=StructureCodec.encode(model.structures)
	check(StructureCodec.decode(payload).valid,"arc structure codec roundtrip")
	model.free()
	model=WorldModel.new()
	check(model.execute(C.arc(Vector2i.ZERO,5,64,total-1.0,2.0)).accepted,"arc wraps circular seam")
	check(model.execute(C.circle_door(model.structures.get_circles()[0].id,total-.5)).accepted,"door across seam is supported by wrapping arc")
	payload=StructureCodec.encode(model.structures)
	check(payload.version==3 and StructureCodec.decode(payload).valid,"partial arcs use compatible v3 schema")
	check(model.execute(C.arc(Vector2i.ZERO,5,64,total-1.0,2.0,true)).accepted and model.structures.get_circles().is_empty(),"full partial-arc erase deletes empty host")
	model.free()
	model=WorldModel.new()
	var join=CircleBoundary.project(full,Vector2(5,1)).point
	# Noninteger orthogonal endpoints must remain exact when joining a curve.
	model.execute(C.wall(Vector2(8,join.y),join,false))
	check(absf(model.structures.get_walls()[0].a.x-join.x)<.000001,"straight wall retains fractional curve endpoint")
	check(StructureCodec.decode(StructureCodec.encode(model.structures)).valid,"fractional straight endpoints roundtrip")
	model.free()
	print("arc_geometry: %d failures"%failures);quit(1 if failures else 0)
