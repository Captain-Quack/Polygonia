extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run_for(sim,seconds: float) -> void:
	for i in range(int(seconds*10)): sim.tick(.1)
func tired(sim,point: Vector2 = Vector2.ZERO):
	var agent = sim.spawn(point)
	agent.body.nourishment = 1.0; agent.body.hunger_rate = 0.0; agent.body.fatigue = .9
	return agent
func _initialize() -> void:
	var definition = load("res://objects/definitions/rest.tres")
	for distance in [0.0,3.0,5.0]:
		var model = WorldModel.new()
		var sim = model.simulation
		var agent = tired(sim)
		var rest = sim.objects.add(definition,Vector2(distance,0))
		var finished := false
		for i in range(300):
			sim.tick(.1)
			if "Rested." in agent.recent_events and agent.action == &"idle":
				check(agent.body.fatigue <= .2,"rest at distance %s continues until recovered" % distance)
				finished = true; break
		check(finished,"visible rest spot at distance %s is used and completed" % distance)
		check(agent.position.distance_to(rest.position) <= .25,"agent actually reached the rest spot")
		check(not rest.providers[0].has_user(agent.id),"completed rest releases capacity")
		check(rest.providers[0].stock == -1 and sim.objects.get_object(rest.id) != null,"rest is not consumed")
		model.free()
	# A long interaction with poor recovery should lose to immediate ground rest.
	var model = WorldModel.new()
	var sim = model.simulation
	var slow = definition.duplicate(true)
	slow.interactions[0].duration = 4.0
	var rest = sim.objects.add(slow,Vector2.ZERO)
	var agent = tired(sim)
	sim.tick(.1)
	check(agent.action == &"resting on ground","rest choice accounts for recovery per unit time")
	model.free()
	# Capacity is held throughout a rest session, then released on removal of its user.
	model = WorldModel.new(); sim = model.simulation
	rest = sim.objects.add(definition,Vector2.ZERO)
	agent = tired(sim)
	var other = tired(sim,Vector2(.1,0))
	run_for(sim,1.2)
	check(rest.providers[0].has_user(agent.id) and not rest.providers[0].has_user(other.id),"only one polygon occupies a rest spot")
	check(other.action == &"resting on ground","busy rest spot leaves ground-rest fallback")
	sim.remove(agent.id)
	check(not rest.providers[0].has_user(agent.id),"removed user releases rest spot")
	run_for(sim,2)
	check(rest.providers[0].has_user(other.id),"waiting polygon can use released rest spot")
	model.free()
	# Deleting or moving a rest spot during a partial rest grants no unearned recovery.
	for move in [false,true]:
		model = WorldModel.new(); sim = model.simulation
		rest = sim.objects.add(definition,Vector2.ZERO)
		agent = tired(sim)
		run_for(sim,.5)
		var before = agent.body.fatigue
		if move: sim.objects.move(rest.id,Vector2(2,0))
		else: sim.objects.remove(rest.id)
		sim.tick(.1)
		check(agent.body.fatigue >= before,"invalidated rest grants no completion effects")
		check(not rest.providers[0].has_user(agent.id),"invalidated rest releases reservation")
		model.free()
	# Urgent food can interrupt rest and release the spot for others.
	model = WorldModel.new(); sim = model.simulation
	rest = sim.objects.add(definition,Vector2.ZERO)
	agent = tired(sim)
	run_for(sim,.5)
	agent.body.nourishment = .01
	sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	run_for(sim,1.0)
	check(agent.action == &"eating","starving polygon interrupts rest for food")
	check(not rest.providers[0].has_user(agent.id),"food interruption releases rest capacity")
	model.free()
	# Known rest spots becoming unreachable must fall back, then recover when reopened.
	model = WorldModel.new(); sim = model.simulation
	agent = tired(sim)
	rest = sim.objects.add(definition,Vector2(3,0))
	sim.tick(.1)
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i(2,-1),Vector2i(4,1))
	run_for(sim,1.5)
	check(agent.action == &"resting on ground","blocked rest spot falls back to ground rest")
	check(agent.recent_events.any(func(event): return event.begins_with("Route unavailable")),"unreachable rest is detected by navigation")
	check(not rest.providers[0].has_user(agent.id),"inaccessible rest spot is not occupied remotely")
	model.execute(StructureCommand.wall(Vector2i(2,-1),Vector2i(2,1),true))
	run_for(sim,5)
	check("Rested." in agent.recent_events,"reopened route makes remembered rest usable again")
	model.free()
	# Verify actual recovery advantage, independent of utility-score calculations.
	model = WorldModel.new(); sim = model.simulation
	agent = tired(sim)
	sim.objects.add(definition,Vector2.ZERO)
	run_for(sim,5)
	var spot_fatigue = agent.body.fatigue
	model.free()
	model = WorldModel.new(); sim = model.simulation
	agent = tired(sim)
	run_for(sim,5)
	check(spot_fatigue < agent.body.fatigue - .1,"rest spots restore fatigue faster than bare ground")
	model.free()
	print("rest_spots: %d failures" % failures); quit(1 if failures else 0)
