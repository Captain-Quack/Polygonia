extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	# Use default spawn physiology, not a manually seeded deprivation value.
	var model = WorldModel.new(); var sim = model.simulation
	var a = sim.spawn(Vector2.ZERO)
	var eligible_health := 0.0
	for i in range(2100):
		sim.tick(.1)
		if eligible_health == 0 and AgentThreatActions.eligible(a,sim.profile()): eligible_health = a.body.health
		if not a.body.alive(): break
	check(eligible_health > .3,"natural starvation reaches extreme eligibility while meaningful reserves remain")
	check(not a.body.alive() and a.action == &"dead","a truly empty world still cannot support indefinite survival")
	model.free()
	# Extreme behavior must be offered from naturally accumulated deprivation.
	model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2.ZERO)
	a.personality.aggression = 1; a.personality.caution = 0
	var reached := false
	for i in range(1950):
		sim.tick(.1)
		if AgentThreatActions.eligible(a,sim.profile()): reached = true; break
	if reached:
		var other = sim.spawn(a.position+Vector2(.3,0))
		sim.tick(.1)
		check(a.controller.current.get("kind") == &"pursue","naturally starved aggressive agent considers a visible living target")
		check(other.body.health < 1,"naturally accumulated emergency behavior can execute a contact attack")
	else: check(false,"natural predation eligibility occurs before death without setting deprivation")
	model.free()
	print("natural_emergencies: %d failures" % failures); quit(1 if failures else 0)
