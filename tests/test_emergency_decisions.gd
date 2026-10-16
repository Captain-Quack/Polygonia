extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run_for(sim,seconds: float) -> void:
	for i in range(int(seconds*10)): sim.tick(.1)
func _initialize() -> void:
	var model = WorldModel.new(); var sim = model.simulation
	var a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = 0; a.body.fatigue = 1; a.body.health = .12
	var food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(3,0))
	var rest = sim.objects.add(load("res://objects/definitions/rest.tres"),Vector2.ZERO)
	sim.tick(.1)
	check(a.action == &"seeking food","critical agent immediately seeks reachable food instead of resting")
	check(not rest.providers[0].has_user(a.id),"urgent feeding does not retain rest")
	run_for(sim,8)
	check(a.body.alive() and food.providers[0].stock == 0,"rest regression survives and eats")
	model.free()
	model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = 0; a.body.fatigue = 1; a.body.health = .25
	run_for(sim,2)
	check(a.position.length() > .5 and a.action == &"searching","unknown food motivates urgent search despite fatigue")
	model.free()
	model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = 0; a.body.health = .02
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	run_for(sim,3)
	check(not a.body.alive() and food.providers[0].stock == 1,"fatal partial meal gives no nutrition")
	check(not food.providers[0].has_user(a.id),"death releases meal")
	model.free()
	model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = 1; a.body.fatigue = 1
	rest = sim.objects.add(load("res://objects/definitions/rest.tres"),Vector2.ZERO)
	run_for(sim,.4)
	a.body.nourishment = 0; a.body.health = .12
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(3,0))
	sim.tick(.1)
	check(a.action == &"seeking food" and not rest.providers[0].has_user(a.id),"emergency interrupts by next tick, refreshing perception")
	model.free()
	# Equal hunger/fatigue, different health: the emergency assessment changes choice.
	var choices: Array = []
	for health in [1.0,.12]:
		model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2.ZERO)
		a.body.nourishment = 0; a.body.fatigue = 1; a.body.health = health
		sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(3,0))
		sim.objects.add(load("res://objects/definitions/rest.tres"),Vector2.ZERO)
		sim.tick(.1); choices.append(a.action); model.free()
	check(choices[0] == &"resting" and choices[1] == &"seeking food","remaining health changes food/rest conflict")
	# A remembered source behind a wall requires actual detour travel time.
	model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2(-2,0))
	a.body.nourishment = .2
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(2,0))
	AgentPerception.observe(a,sim.objects,model,0)
	model.execute(StructureCommand.wall(Vector2i(0,-2),Vector2i(0,2),false))
	a.assessment = EmergencyAssessment.evaluate(a.body,sim.profile())
	var options = AgentDecision.candidates(a,0,model.structures.traversal_revision,sim)
	var known = options.filter(func(o): return o.key == "%d:0" % food.id)
	check(known.size() == 1 and known[0].relief_after > 4.0/a.effective_speed()+2,"relief timing includes wall detour")
	model.free()
	print("emergency_decisions: %d failures" % failures); quit(1 if failures else 0)
