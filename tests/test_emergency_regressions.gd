extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var model = WorldModel.new(); var sim = model.simulation
	var a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = 0; a.body.health = .3; a.body.deprivation = 1; a.personality.aggression = 0
	for i in range(4): sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	for i in range(25): sim.tick(.1)
	check(a.body.nourishment > .4 and sim.objects.all().size() == 3,"rotating consideration cannot interrupt a feasible meal")
	model.free()
	# Plenty of rest alternatives must not hide ordinary food from predation policy.
	model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = 0; a.body.deprivation = 1; a.body.fatigue = 1
	a.personality.aggression = 1; a.personality.caution = 0
	for i in range(4): sim.objects.add(load("res://objects/definitions/rest.tres"),Vector2.ZERO)
	var food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	sim.spawn(Vector2(1,0))
	var attacked := false
	for i in range(21):
		sim.tick(.1)
		attacked = attacked or a.controller.current.get("kind") == &"pursue"
	check(not attacked and food.providers[0].stock == 0,"ordinary food stays visible to predation policy across budget rotation")
	model.free()
	# Admission is checked when starting; external relief need not cancel a reserved meal.
	model = WorldModel.new(); sim = model.simulation
	var dead = sim.spawn(Vector2.ZERO); dead.body.damage(2); sim.tick(.1)
	var corpse = sim.objects.all()[0]
	a = sim.spawn(Vector2.ZERO); a.body.nourishment = 0; a.body.deprivation = 1; a.personality.aggression = 0
	for i in range(10): sim.tick(.1)
	a.body.apply_effects({&"nourishment":.15})
	for i in range(12): sim.tick(.1)
	check(corpse.providers[0].stock == 0 and a.body.nourishment > .5,"an admitted corpse meal can finish after eligibility changes")
	model.free()
	print("emergency_regressions: %d failures" % failures); quit(1 if failures else 0)
