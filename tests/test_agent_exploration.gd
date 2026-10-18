extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func explorer(sim):
	var a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = .5; a.body.hunger_rate = 0; a.body.fatigue = 0; a.body.fatigue_rate = 0
	return a
func _initialize() -> void:
	var final_positions: Array = []
	for replay in range(2):
		var model = WorldModel.new(); var sim = model.simulation
		var a = explorer(sim)
		var length := 0.0
		for i in range(600):
			var before = a.position; sim.tick(.1); length += before.distance_to(a.position)
		check(a.position.length() > 30,"open-ground exploration makes sustained progress beyond the original loop")
		check(a.position.length()/length > .5,"exploration does not cancel most traveled distance")
		final_positions.append(a.position); model.free()
	check(final_positions[0] == final_positions[1],"exploration is reproducible for the same seed")
	# Discover food that the old four-cell loop could never bring into view.
	var model = WorldModel.new(); var sim = model.simulation
	var a = explorer(sim)
	var food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.from_angle(a.exploration.heading)*12)
	for i in range(180): sim.tick(.1)
	check(food.providers[0].stock == 0,"continued exploration discovers food outside the original search area")
	model.free()
	# At a dead end, a previously visited corridor must remain a legal escape.
	model = WorldModel.new(); sim = model.simulation; a = explorer(sim)
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i(-10,-1),Vector2i(2,1))
	a.exploration.heading = 0
	a.exploration.reached(Vector2(-4,0)); a.exploration.reached(Vector2.ZERO)
	var route = a.exploration.choose(a,sim.navigation)
	check(not route.is_empty(),"recent-place memory permits necessary backtracking at a dead end")
	if not route.is_empty():
		check(route.points[-1].x < -3,"blocked forward exploration turns into the reachable corridor")
		var before = a.position
		for point in route.points:
			check(not model.physical.sweep(before,point,a.radius).hit,"exploration fallback respects wall clearance")
			before = point
	model.free()
	print("agent_exploration: %d failures" % failures); quit(1 if failures else 0)
