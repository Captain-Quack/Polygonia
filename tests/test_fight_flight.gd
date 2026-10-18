extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run_for(sim,seconds: float) -> void:
	for i in range(int(seconds*10)): sim.tick(.1)
func _initialize() -> void:
	var model = WorldModel.new(); var sim = model.simulation
	var attacker = sim.spawn(Vector2(.3,0)); var defender = sim.spawn(Vector2.ZERO)
	attacker.body.health = .2
	defender.body.nourishment = 1; defender.body.fatigue = 0; defender.personality.caution = .3
	sim.combat.queue_strike(attacker.id,defender.id,false); sim.combat.resolve(sim)
	sim.tick(.1)
	check(defender.action == &"defending" and attacker.body.health < .2,"healthy clear-headed agent can defend against a weaker attacker despite an escape route")
	attacker.position = Vector2(20,0)
	var position = defender.position
	run_for(sim,4)
	check(defender.position.distance_to(position) < 5 and defender.threats.is_empty(),"defense does not chase a withdrawn opponent or sustain hostility indefinitely")
	model.free()
	model = WorldModel.new(); sim = model.simulation
	attacker = sim.spawn(Vector2(.3,0)); defender = sim.spawn(Vector2.ZERO)
	defender.body.health = .3; defender.body.nourishment = 1; defender.body.fatigue = 0
	sim.combat.queue_strike(attacker.id,defender.id,false); sim.combat.resolve(sim)
	sim.tick(.1)
	check(defender.action == &"fleeing" and defender.position.x < 0,"vulnerable agent escapes a stronger attacker")
	model.free()
	# Fleeing should not cross through a second known attacker to escape the first.
	model = WorldModel.new(); sim = model.simulation
	defender = sim.spawn(Vector2.ZERO); defender.body.health = .3; defender.body.nourishment = 1
	var left = sim.spawn(Vector2(-.3,0)); var right = sim.spawn(Vector2(.6,0))
	sim.combat.queue_strike(left.id,defender.id,false); sim.combat.resolve(sim)
	defender.threats[right.id] = {"position":right.position,"until":3.0}
	sim.tick(.1)
	check(defender.action == &"fleeing","outnumbered agent chooses escape")
	var previous = Vector2.ZERO
	for point in defender.controller.route_points:
		var clearance = Geometry2D.get_closest_point_to_segment(right.position,previous,point).distance_to(right.position)
		check(clearance >= .2,"escape route avoids crossing through another known attacker")
		previous = point
	model.free()
	# A visibly dead former attacker must not hide a current attacker from defense.
	model = WorldModel.new(); sim = model.simulation
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i.ZERO,Vector2i.ONE)
	defender = sim.spawn(Vector2(.3,.5)); defender.body.nourishment = 1; defender.body.fatigue = 0
	var dead = sim.spawn(Vector2(.35,.5)); dead.body.health = 0
	attacker = sim.spawn(Vector2(.7,.5)); attacker.body.health = .2
	defender.threats[dead.id] = {"position":dead.position,"until":3.0}
	defender.threats[attacker.id] = {"position":attacker.position,"until":3.0}
	sim.tick(.1)
	check(defender.action == &"defending" and not defender.threats.has(dead.id),"observed death clears obsolete threats and preserves defense against living attackers")
	model.free()
	print("fight_flight: %d failures" % failures); quit(1 if failures else 0)
