extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var pressure: Array = []
	for confined in [false,true]:
		var model = WorldModel.new(); var sim = model.simulation
		var a = sim.spawn(Vector2.ZERO)
		if a.get("desperation") == null:
			check(false,"desperation is represented separately from deprivation"); model.free(); quit(1); return
		if confined: load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i(-1,-1),Vector2i(1,1))
		for i in range(1500): sim.tick(.1)
		pressure.append(a.desperation)
		if confined:
			check(AgentThreatActions.eligible(a,sim.profile()) and a.body.deprivation < sim.profile().predation_deprivation,"urgent blocked agent can consider extreme feeding before accumulated impairment alone permits it")
			a.personality.aggression = 1; a.personality.caution = 0
			var other = sim.spawn(a.position+Vector2(.3,0))
			sim.tick(.1)
			check(a.controller.current.get("kind") == &"pursue" and other.body.health < 1,"constrained desperate agent actually attacks for survival")
			sim.remove(other.id)
			var food = sim.objects.add(load("res://objects/definitions/food.tres"),a.position)
			for i in range(30): sim.tick(.1)
			check(food.providers[0].stock == 0 and a.desperation < .1,"successful nourishment relieves desperation")
		model.free()
	check(pressure[1] > pressure[0]+.2,"unmet needs with repeated failed routes increase desperation more than free searching")
	var model = WorldModel.new(); var sim = model.simulation; var a = sim.spawn(Vector2.ZERO)
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i(-1,-1),Vector2i(1,1))
	var food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	food.providers[0].stock = 20
	for i in range(1800): sim.tick(.1)
	check(a.body.alive() and a.desperation < .2,"confinement with sufficient nourishment does not produce desperate violence")
	model.free()
	print("constraint_desperation: %d failures" % failures); quit(1 if failures else 0)
