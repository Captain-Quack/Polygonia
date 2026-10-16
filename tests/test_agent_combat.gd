extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func extreme(a) -> void:
	a.body.nourishment = 0; a.body.deprivation = .9; a.personality.aggression = 1; a.personality.caution = 0
func _initialize() -> void:
	if not ResourceLoader.exists("res://agents/combat_system.gd"):
		check(false,"combat system exists"); quit(1); return
	var model = WorldModel.new(); var sim = model.simulation
	var a = sim.spawn(Vector2.ZERO); var b = sim.spawn(Vector2(1,0))
	a.body.nourishment = 0; a.personality.aggression = 1
	sim.tick(.1)
	check(a.controller.current.get("kind") != &"pursue","ordinary starvation does not permit predation")
	extreme(a); sim.tick(.1)
	check(a.controller.current.get("kind") == &"pursue","extreme aggressive agent can pursue a living target")
	var target_snapshot: Vector2 = a.agent_beliefs[b.id].position
	b.position = Vector2(20,0); sim.tick(.1)
	check(a.agent_beliefs.get(b.id,{}).get("position",target_snapshot) != b.position,"pursuit cannot know unseen live position")
	model.free()
	model = WorldModel.new(); sim = model.simulation
	a = sim.spawn(Vector2.ZERO); b = sim.spawn(Vector2(1,0)); extreme(a); a.personality.aggression = 0
	sim.tick(.1); check(a.controller.current.get("kind") != &"pursue","zero aggression rejects predation")
	a.personality.aggression = 1
	sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	sim.tick(.1); check(a.action == &"eating","ordinary food suppresses extreme attacks")
	model.free()
	model = WorldModel.new(); sim = model.simulation
	a = sim.spawn(Vector2.ZERO); b = sim.spawn(Vector2(.3,0))
	a.body.hunger_rate = 0; b.body.hunger_rate = 0
	var rest = sim.objects.add(load("res://objects/definitions/rest.tres"),b.position)
	b.body.fatigue = 1; b.body.nourishment = 1; sim.tick(.1)
	sim.combat.queue_strike(a.id,b.id,false); sim.combat.resolve(sim)
	check(b.body.health < 1,"contact strike damages")
	var health = b.body.health
	sim.combat.queue_strike(a.id,b.id,false); sim.combat.resolve(sim)
	check(b.body.health == health,"cooldown survives repeated queueing")
	sim.tick(.1)
	check(b.action == &"fleeing" and not rest.providers[0].has_user(b.id),"direct threat interrupts rest on next tick")
	model.free()
	for reverse in [false,true]:
		model = WorldModel.new(); sim = model.simulation
		a = sim.spawn(Vector2.ZERO); b = sim.spawn(Vector2(.3,0))
		a.body.health = .05; b.body.health = .05
		if reverse: sim.agents.reverse()
		sim.combat.queue_strike(a.id,b.id,false); sim.combat.queue_strike(b.id,a.id,false)
		sim.combat.resolve(sim)
		check(not a.body.alive() and not b.body.alive(),"simultaneous lethal strikes are order independent")
		model.free()
	model = WorldModel.new(); sim = model.simulation
	a = sim.spawn(Vector2.ZERO); b = sim.spawn(Vector2(2,0))
	sim.combat.queue_strike(a.id,b.id,false); sim.combat.resolve(sim)
	check(b.body.health == 1,"no damage out of contact range")
	sim.remove(b.id); sim.combat.queue_strike(a.id,b.id,false); sim.combat.resolve(sim)
	check(a.body.health == 1,"removed targets are safe")
	model.free()
	print("agent_combat: %d failures" % failures); quit(1 if failures else 0)
