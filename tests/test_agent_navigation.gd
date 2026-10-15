extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	if not ResourceLoader.exists("res://agents/agent_navigation.gd"):
		check(false,"Agent navigator exists"); quit(1); return
	var model = WorldModel.new()
	var nav = load("res://agents/agent_navigation.gd").new(model)
	model.execute(StructureCommand.wall(Vector2i(0,-2),Vector2i(0,2),false))
	var route = nav.route(Vector2(-2,0),Vector2(2,0),0.2)
	check(route.status == &"OK" and route.points.size() > 1,"route detours around finite wall")
	var prev = Vector2(-2,0)
	for point in route.points:
		check(not model.physical.sweep(prev,point,0.2).hit,"every route segment clears body")
		prev = point
	model.free()
	model = WorldModel.new(); nav = load("res://agents/agent_navigation.gd").new(model)
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i.ZERO,Vector2i(4,4))
	model.execute(StructureCommand.place_door(Vector2i(1,0),Vector2i(2,0)))
	var door = model.structures.get_doors()[0].id
	check(nav.route(Vector2(1.5,1),Vector2(1.5,-1),0.2).status == &"OK","unlocked closed door is a route opportunity")
	check(nav.prepare_step(Vector2(1.5,0.5),Vector2(1.5,-0.5),0.2,1),"movement opens door before crossing")
	check(model.structures.get_door(door).state == &"OPEN","door physically opened")
	model.execute(StructureCommand.door_action(door,&"CLOSE"))
	model.execute(StructureCommand.door_action(door,&"LOCK"))
	check(nav.route(Vector2(1.5,1),Vector2(1.5,-1),0.2).status != &"OK","locked enclosure is inaccessible")
	model.execute(StructureCommand.door_action(door,&"UNLOCK"))
	check(nav.route(Vector2(1.5,1),Vector2(1.5,-1),0.2).status == &"OK","unlock invalidates blocked route cache")
	model.free()
	model = WorldModel.new(); nav = load("res://agents/agent_navigation.gd").new(model)
	model.execute(StructureCommand.circle(Vector2i.ZERO,3,64))
	check(nav.route(Vector2.ZERO,Vector2(4,0),0.2).status != &"OK","circular wall encloses agent")
	model.execute(StructureCommand.circle(Vector2i.ZERO,3,64,true))
	check(nav.route(Vector2.ZERO,Vector2(4,0),0.2).status == &"OK","removed circular wall reopens route")
	check(nav.route(Vector2(INF,0),Vector2.ZERO,0.2).status == &"INVALID","invalid coordinates rejected")
	model.free()
	print("agent_navigation: %d failures" % failures); quit(1 if failures else 0)
