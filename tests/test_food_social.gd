extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run_for(sim,seconds: float) -> void:
	for i in range(roundi(seconds*10)): sim.tick(.1)
func holder(sim,health: float = 1.0):
	var a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = .5; a.body.health = health; a.body.hunger_rate = 0; a.body.fatigue_rate = 0
	a.personality.set("kindness",0.0); a.personality.caution = 0
	return a
func hungry(sim,point: Vector2,desperate: bool = false):
	var a = sim.spawn(point)
	a.body.nourishment = 0 if desperate else .1
	a.body.deprivation = .9 if desperate else 0.0
	a.body.hunger_rate = 0; a.body.fatigue_rate = 0
	a.personality.aggression = 1; a.personality.caution = 0; a.personality.set("kindness",0.0)
	return a
func _initialize() -> void:
	var model = WorldModel.new(); var sim = model.simulation
	var a = holder(sim); a.personality.set("kindness",1.0)
	var food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	sim.tick(.1)
	var b = hungry(sim,Vector2(.35,0))
	sim.tick(.1)
	check(sim.objects.all().size() == 2,"kind holder splits food for a nearby hungry agent")
	check(food.providers[0].has_user(a.id),"sharing preserves donor's meal reservation")
	var c = hungry(sim,Vector2(0,.35))
	run_for(sim,.7)
	check(sim.objects.all().size() == 3,"three hungry neighbors can receive one circle each")
	run_for(sim,3)
	check(b.body.nourishment > .1 and c.body.nourishment > .1,"recipients actually eat their shared circles")
	check(is_equal_approx(a.body.nourishment+b.body.nourishment+c.body.nourishment,.5+.1+.1+.45),"sharing does not create nutrition")
	model.free()
	model = WorldModel.new(); sim = model.simulation; a = holder(sim)
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO); sim.tick(.1)
	b = hungry(sim,Vector2(.35,0)); sim.tick(.1)
	check(sim.objects.all().size() == 1,"zero-kindness holder does not donate")
	model.free()
	# A weak holder gives up its claim while escaping a desperate challenger.
	model = WorldModel.new(); sim = model.simulation; a = holder(sim,.2)
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO); sim.tick(.1)
	b = hungry(sim,Vector2(.4,0),true); sim.tick(.1)
	check(b.controller.current.get("kind") == &"contest_food","desperate challenger contests the meal rather than killing for a corpse")
	run_for(sim,.5)
	check(food.providers[0].has_user(b.id) and not food.providers[0].has_user(a.id),"fleeing holder surrenders food to challenger")
	model.free()
	# A strong defender keeps its reservation during combat.
	model = WorldModel.new(); sim = model.simulation; a = holder(sim)
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO); sim.tick(.1)
	b = hungry(sim,Vector2(.4,0),true); b.body.health = .3
	run_for(sim,.3)
	check(a.action == &"defending" and food.providers[0].has_user(a.id),"strong holder defends without releasing its food")
	check(b.body.health < .3,"food defense can damage the challenger")
	model.free()
	# Freely accessible food is preferable to a fight over food.
	model = WorldModel.new(); sim = model.simulation; a = holder(sim)
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO); sim.tick(.1)
	b = hungry(sim,Vector2(.4,0),true)
	sim.objects.add(load("res://objects/definitions/food.tres"),b.position)
	sim.tick(.1)
	check(b.action == &"eating" and a.body.health == 1,"available food suppresses food contests")
	model.free()
	# Visible food moved behind a wall cannot be shared or contested remotely.
	model = WorldModel.new(); sim = model.simulation; a = holder(sim); a.personality.set("kindness",1.0)
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO); sim.tick(.1)
	b = hungry(sim,Vector2(.4,0),true)
	model.execute(StructureCommand.wall(Vector2(0.25,-2),Vector2(.25,2),false))
	sim.tick(.1)
	check(sim.objects.all().size() == 1 and b.controller.current.get("kind") != &"contest_food","walls prevent unseen sharing and claims")
	model.free()
	print("food_social: %d failures" % failures); quit(1 if failures else 0)
