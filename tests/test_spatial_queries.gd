extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	if not ResourceLoader.exists("res://spatial/physical_queries.gd"):
		check(false,"Physical query service exists");quit(1);return
	var C=load("res://structures/structure_command.gd")
	var model=load("res://world/world_model.gd").new()
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i.ZERO,Vector2i(4,4))
	model.execute(C.place_door(Vector2i(1,0),Vector2i(2,0)))
	var id=model.structures.get_doors()[0].id
	var region_id=model.regions.locate(Vector2(1,1)).region_id
	var rebuilds=model.regions.rebuild_count
	check(model.physical.sweep(Vector2(1.5,-1),Vector2(1.5,1),.2).hit,"closed door blocks")
	check(model.physical.crossing_option(id,{"radius":.2,"can_open_doors":true}).kind==&"OPEN_THEN_PASS","opener gets door action")
	check(model.physical.crossing_option(id,{"radius":.2,"can_open_doors":false}).kind==&"BLOCKED","non opener blocked")
	check(model.execute(C.door_action(id,&"OPEN")).accepted,"open unlocked")
	check(not model.physical.sweep(Vector2(1.5,-1),Vector2(1.5,1),.2).hit,"open aperture allows small body")
	check(model.physical.sweep(Vector2(1.5,-1),Vector2(1.5,1),.5).hit,"large body blocked by jamb")
	check(model.physical.visibility_hits(Vector2(1.5,-1),Vector2(1.5,1)).is_empty(),"open aperture permits sight")
	check(not model.execute(C.door_action(id,&"LOCK")).accepted,"cannot lock open door")
	model.occupancy_query=func(_capsule):return true
	check(not model.execute(C.door_action(id,&"CLOSE")).accepted,"cannot close onto body")
	model.occupancy_query=func(_capsule):return false
	check(model.execute(C.door_action(id,&"CLOSE")).accepted,"close clear doorway")
	var barrier_revision=model.structures.barrier_revision
	model.execute(C.door_action(id,&"LOCK"))
	check(model.structures.barrier_revision==barrier_revision,"lock doesn't alter occlusion")
	check(not model.execute(C.door_action(id,&"OPEN")).accepted,"locked door rejects opening")
	check(model.physical.crossing_option(id,{"radius":.2,"can_open_doors":true}).kind==&"BLOCKED","locked door blocks opener")
	check(model.regions.rebuild_count==rebuilds and model.regions.locate(Vector2(1,1)).region_id==region_id,"door state preserves topology")
	check(model.execute(C.door_action(id,&"UNLOCK")).accepted,"unlock")
	check(model.physical.sweep(Vector2(-1,1),Vector2(5,1),0).hit,"long sweep crosses wall")
	check(model.physical.sweep(Vector2(-1,0),Vector2(0,-1),1).hit,"swept body cannot cut corner")
	check(not model.physical.sweep(Vector2.ZERO,Vector2.ONE,-1).valid,"negative radius invalid")
	check(not model.physical.visibility_hits(Vector2(1.5,-1),Vector2(1.5,1)).is_empty(),"closed aperture blocks sight")
	model.free()
	check(not is_finite(PhysicalQueries.capsule_time(Vector2(-1000000,.94999),Vector2(1000000,.94999),Vector2(0,1),Vector2(0,2),.05)),"long near-miss remains clear")
	print("spatial_queries: %d failures"%failures);quit(1 if failures else 0)
