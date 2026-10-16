extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run_for(sim,seconds: float) -> void:
	for i in range(int(seconds*10)): sim.tick(.1)
func _initialize() -> void:
	var model = WorldModel.new()
	var sim = model.simulation
	var food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	check(food.providers[0].stock == 1,"default food contains one finite serving")
	var a = sim.spawn(Vector2.ZERO); a.body.nourishment = .1
	var b = sim.spawn(Vector2(.1,0)); b.body.nourishment = .1
	run_for(sim,4)
	check(sim.objects.get_object(food.id) == null,"consumed food disappears from world")
	check((a.body.nourishment > .3) != (b.body.nourishment > .3),"only one agent receives the serving")
	check(food.providers[0].stock == 0,"consumed food has no remaining stock")
	var combined_nutrition = a.body.nourishment + b.body.nourishment
	run_for(sim,10)
	check(a.body.nourishment + b.body.nourishment < combined_nutrition,"depleted food cannot feed agents again")
	var rest = sim.objects.add(load("res://objects/definitions/rest.tres"),Vector2.ZERO)
	run_for(sim,1)
	check(sim.objects.get_object(rest.id) != null,"unlimited resting opportunities remain")
	model.free()
	print("food_depletion: %d failures" % failures); quit(1 if failures else 0)
