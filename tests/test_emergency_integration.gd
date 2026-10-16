extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var model = WorldModel.new(); var sim = model.simulation
	var a = sim.spawn(Vector2.ZERO)
	if not a.has_method("inspection_text"):
		check(false,"inspection exposes emergency reasons and state"); model.free(); quit(1); return
	a.body.nourishment = 0; a.body.health = .12
	sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(3,0))
	sim.tick(.1)
	check("Urgency" in a.inspection_text() and "Deprivation" in a.inspection_text(),"inspection reports emergency state")
	check("Food cannot wait" in a.inspection_text(),"inspection explains urgent choice")
	var profile = sim.profile(); profile.strike_damage = 99
	check(sim.profile().strike_damage == .1,"returned profile cannot mutate simulation policy")
	profile.strike_damage = NAN
	check(not sim.configure(profile),"simulation rejects invalid profiles")
	for i in range(600): sim.tick(.1)
	check(is_finite(a.body.health) and is_finite(a.body.deprivation) and is_finite(a.position.x),"long run keeps state finite")
	model.free()
	# A separating wall prevents contact damage even when centers are in contact range.
	model = WorldModel.new(); sim = model.simulation
	a = sim.spawn(Vector2(-.23,0)); var b = sim.spawn(Vector2(.23,0))
	model.execute(StructureCommand.wall(Vector2i(0,-1),Vector2i(0,1),false))
	sim.combat.queue_strike(a.id,b.id,false); sim.combat.resolve(sim)
	check(b.body.health == 1,"walls block contact damage")
	model.free()
	# Death is materialized once, including simultaneous lethal combat.
	model = WorldModel.new(); sim = model.simulation
	a = sim.spawn(Vector2.ZERO); b = sim.spawn(Vector2(.3,0))
	a.body.health = .05; b.body.health = .05
	sim.combat.queue_strike(a.id,b.id,true); sim.combat.queue_strike(b.id,a.id,true)
	sim.combat.resolve(sim); sim.tick(.1); sim.tick(.1)
	check(sim.objects.all().size() == 2 and a.death_handled and b.death_handled,"simultaneous deaths create one corpse each")
	check(a.body.nourishment < .66 and b.body.nourishment < .66,"kills give no immediate nutrition")
	model.free()
	print("emergency_integration: %d failures" % failures); quit(1 if failures else 0)
