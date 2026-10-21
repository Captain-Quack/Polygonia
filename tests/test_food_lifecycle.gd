extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run_for(sim,seconds: float) -> void:
	for i in range(roundi(seconds*10)): sim.tick(.1)
func _initialize() -> void:
	# Interrupted split meals remain finite and can be reclaimed after death/removal.
	var model = WorldModel.new(); var sim = model.simulation
	var donor = sim.spawn(Vector2.ZERO); donor.body.nourishment = .5; donor.personality.kindness = 0
	var receiver = sim.spawn(Vector2(.4,0)); receiver.body.nourishment = .2; receiver.personality.kindness = 0
	var food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	food.providers[0].begin(donor.id)
	var portion = sim.objects.share_food(food.id,donor.id,receiver.id,receiver.position)
	AgentFoodSocial.adopt(receiver,portion,sim,"Received food.")
	check(portion.providers[0].has_user(receiver.id),"recipient owns the split meal")
	sim.remove(receiver.id)
	check(portion.providers[0].available() and portion.providers[0].portion_count() == 1,"removing recipient releases uneaten circle")
	var survivor = sim.spawn(Vector2(.4,0)); survivor.body.nourishment = .2; survivor.body.hunger_rate = 0; survivor.personality.kindness = 0
	# Release donor's test-only admission and remove it to isolate the single circle.
	sim.objects.remove(food.id); sim.remove(donor.id)
	run_for(sim,3)
	check(is_equal_approx(survivor.body.nourishment,.35),"one reclaimed circle grants one third of a serving")
	model.free()
	for mutation in ["move","remove"]:
		model = WorldModel.new(); sim = model.simulation
		donor = sim.spawn(Vector2.ZERO); donor.body.nourishment = .5; donor.personality.kindness = 0
		food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO); sim.tick(.1)
		receiver = sim.spawn(Vector2(1,0)); receiver.body.nourishment = 0; receiver.body.deprivation = .9; receiver.personality.aggression = 1; receiver.personality.kindness = 0
		sim.tick(.1)
		check(receiver.controller.current.get("kind") == &"contest_food","contest started before resource mutation")
		if mutation == "move": sim.objects.move(food.id,Vector2(20,0))
		else: sim.objects.remove(food.id)
		sim.tick(.1)
		check(receiver.controller.current.get("kind") != &"contest_food" and receiver.body.nourishment == 0,"stale contested food cannot be stolen after "+mutation)
		model.free()
	# A defended meal pauses; returning to that same reserved meal keeps progress.
	model = WorldModel.new(); sim = model.simulation
	donor = sim.spawn(Vector2.ZERO); donor.body.nourishment = .5; donor.personality.kindness = 0; donor.personality.caution = 0
	food = sim.objects.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	run_for(sim,1.0)
	receiver = sim.spawn(Vector2(.4,0)); receiver.body.nourishment = 0; receiver.body.health = .3; receiver.body.deprivation = .9; receiver.personality.aggression = 1
	run_for(sim,.2)
	var held_progress = donor.controller.progress
	check(donor.action == &"defending" and food.providers[0].has_user(donor.id),"defender still holds its interrupted meal")
	sim.remove(receiver.id); donor.threats.clear(); donor.next_decision = sim.time
	sim.tick(.1)
	check(donor.controller.progress >= held_progress and donor.action == &"eating","defended meal resumes without restarting consumption")
	model.free()
	print("food_lifecycle: %d failures" % failures); quit(1 if failures else 0)
