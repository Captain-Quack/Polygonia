extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run_for(sim,seconds: float) -> void:
	for i in range(int(seconds * 10)): sim.tick(0.1)
func _initialize() -> void:
	if not ResourceLoader.exists("res://agents/agent_simulation.gd"):
		check(false,"Agent simulation exists"); quit(1); return
	var model = WorldModel.new()
	var sim = load("res://agents/agent_simulation.gd").new(model)
	var a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = 0.2
	var food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(3,0))
	run_for(sim,10)
	check(a.body.nourishment > 0.5 and food.providers[0].stock < 8,"agent autonomously finds and eats food")
	a.body.fatigue = 0.95; a.body.nourishment = 1.0
	var rest = sim.objects.add(load("res://objects/definitions/rest.tres"),a.position + Vector2(1,0))
	run_for(sim,12)
	check(a.body.fatigue < 0.6,"tired agent uses rest opportunity")
	sim.objects.remove(rest.id); a.body.fatigue = 0.9
	run_for(sim,10)
	check(a.body.fatigue < 0.8,"ground rest remains possible without furniture")
	model.free()
	model = WorldModel.new(); sim = load("res://agents/agent_simulation.gd").new(model)
	a = sim.spawn(Vector2.ZERO); a.body.nourishment = 0.15
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(3,0))
	sim.tick(0.1)
	var key = a.beliefs.keys()[0]
	a.position = Vector2(-6,0)
	sim.objects.move(food.id,Vector2(20,0))
	sim.tick(0.1)
	check(a.beliefs[key].position == Vector2(3,0),"unseen movement does not update memory")
	a.position = Vector2(3,0)
	sim.tick(0.5)
	check(not a.beliefs.has(key),"empty remembered location invalidates belief")
	model.free()
	model = WorldModel.new(); sim = load("res://agents/agent_simulation.gd").new(model)
	a = sim.spawn(Vector2.ZERO); a.body.nourishment = 0.2
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	run_for(sim,0.5)
	check(a.controller.provider != null,"agent begins timed eating")
	sim.objects.remove(food.id)
	run_for(sim,3)
	check(a.body.nourishment < 0.2,"removed food grants no nutrition")
	model.free()
	model = WorldModel.new(); sim = load("res://agents/agent_simulation.gd").new(model)
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	food.providers[0].stock = 1
	a = sim.spawn(Vector2(-0.2,0)); a.body.nourishment = 0.1
	var b = sim.spawn(Vector2(0.2,0)); b.body.nourishment = 0.1
	run_for(sim,4)
	check(food.providers[0].stock == 0,"two agents consume only one last portion")
	check((a.body.nourishment > 0.3) != (b.body.nourishment > 0.3),"only successful eater receives nutrition")
	a.body.damage(2); var stopped = a.position
	run_for(sim,2)
	check(a.position == stopped and a.action == &"dead","dead agent stops acting")
	model.free()
	model = WorldModel.new(); sim = load("res://agents/agent_simulation.gd").new(model)
	a = sim.spawn(Vector2.ZERO); a.body.nourishment = 0.2
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(3,0))
	sim.tick(0.1)
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i(-1,-1),Vector2i(1,1))
	run_for(sim,1)
	check(absf(a.position.x) < 0.8 and absf(a.position.y) < 0.8,"new enclosure cannot be walked through")
	check(not a.beliefs.is_empty() and a.beliefs.values()[0].retry_at > sim.time,"failed food route receives retry cooldown")
	var original_stock = food.providers[0].stock
	model.execute(StructureCommand.wall(Vector2i(1,-1),Vector2i(1,1),true))
	run_for(sim,8)
	check(food.providers[0].stock < original_stock,"reopened route lets agent resume eating")
	model.free()
	model = WorldModel.new(); sim = load("res://agents/agent_simulation.gd").new(model)
	a = sim.spawn(Vector2.ZERO); a.body.nourishment = 0.2
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(3,0))
	sim.tick(0.1)
	sim.objects.move(food.id,Vector2(0,3))
	run_for(sim,8)
	check(food.providers[0].stock < 8,"visible relocation redirects agent to new food location")
	model.free()
	print("agent_simulation: %d failures" % failures); quit(1 if failures else 0)
