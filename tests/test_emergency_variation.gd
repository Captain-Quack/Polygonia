extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var model = WorldModel.new(); var sim = model.simulation
	var a = sim.spawn(Vector2.ZERO); var b = sim.spawn(Vector2(0,1))
	a.body.nourishment = .3; b.body.nourishment = .3
	b.body.deprivation = 1
	sim.tick(.1)
	check(b.effective_speed() < a.effective_speed(),"prolonged deprivation slows movement at equal hunger")
	if not a.has_method("consideration_limit"):
		check(false,"impairment bounds alternative consideration"); model.free(); quit(1); return
	check(a.consideration_limit() == 8 and b.consideration_limit() == 2,"impairment considers fewer alternatives with minimum two")
	b.body.apply_effects({&"nourishment":.45})
	check(b.body.deprivation > .9,"meal preserves accumulated impairment")
	var food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(2,0))
	AgentPerception.observe(a,sim.objects,model,sim.time)
	var key = "%d:0" % food.id
	a.familiarity[key] = 10; a.body.deprivation = 1; a.personality.persistence = 1
	a.beliefs[key].retry_at = sim.time+8; a.beliefs[key].failed_revision = model.structures.traversal_revision
	var options = AgentDecision.candidates(a,sim.time,model.structures.traversal_revision,sim)
	check(not options.any(func(o): return o.key == key),"familiarity cannot override a failed route")
	model.free()
	var positions: Array = []
	for replay in range(2):
		model = WorldModel.new(); sim = model.simulation; sim.seed_value = 93
		a = sim.spawn(Vector2.ZERO); a.body.nourishment = .1
		for i in range(40): sim.tick(.1)
		positions.append(a.position); model.free()
	check(positions[0] == positions[1],"identical seed and starting state reproduce behavior")
	print("emergency_variation: %d failures" % failures); quit(1 if failures else 0)
