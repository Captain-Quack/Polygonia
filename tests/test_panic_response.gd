extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run_for(sim,seconds: float) -> void:
	for i in range(int(seconds*10)): sim.tick(.1)
func _initialize() -> void:
	var model = WorldModel.new(); var sim = model.simulation
	var a = sim.spawn(Vector2(.5,.5))
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i.ZERO,Vector2i.ONE)
	var panicked := false
	for i in range(1900):
		sim.tick(.1)
		panicked = panicked or a.action == &"panicking"
		if panicked: break
	check(panicked and a.body.alive(),"natural urgent confinement becomes panic before death")
	check("way out" in a.decision_reason,"panic explains the immediate search response")
	if panicked:
		check(a.controller.wait_until-sim.time <= .8,"panic shortens failed-route retry delay")
		check(a.next_decision <= sim.time+.11,"panic reconsiders opportunities on the next fixed tick even while waiting")
		# Opening the enclosure should reconsider immediately, not sit out the old wait.
		model.execute(StructureCommand.wall(Vector2i(0,0),Vector2i(1,0),true))
		var before = a.position
		sim.tick(.1)
		check(a.position.distance_to(before) > 0,"new opening is considered immediately during panic wait")
		var food = sim.objects.add(load("res://objects/definitions/food.tres"),a.position)
		run_for(sim,3)
		check(food.providers[0].stock == 0 and a.action != &"panicking","nourishment ends panic without an independent state reset")
	model.free()
	# Cramped navigable spaces need shorter probes; they are not complete immobility.
	model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2.ZERO)
	a.body.nourishment = .5; a.body.hunger_rate = 0; a.body.fatigue_rate = 0
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i(-1,-1),Vector2i(1,1))
	run_for(sim,2)
	check(a.position.length() > .1,"short nearby destinations permit movement inside a cramped room")
	check(a.action != &"panicking","one setback without urgent need does not produce panic")
	model.free()
	# A completely immobile but comfortably fed agent may wait calmly.
	model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2(.5,.5))
	a.body.nourishment = 1; a.body.hunger_rate = 0; a.body.fatigue_rate = 0
	load("res://tests/structure_fixtures.gd").rectangle(model,Vector2i.ZERO,Vector2i.ONE)
	a.controller.reconsider(a,[{"kind":&"explore","key":"explore","score":100}],0)
	a.next_decision = 100
	run_for(sim,20)
	check(a.action == &"waiting: no route" and a.desperation < .1,"comfortable failed navigation stays calm")
	model.free()
	print("panic_response: %d failures" % failures); quit(1 if failures else 0)
