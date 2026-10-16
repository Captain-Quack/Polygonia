extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var model = WorldModel.new(); var sim = model.simulation
	var dead = sim.spawn(Vector2.ZERO); dead.body.damage(2)
	sim.tick(.1)
	check(sim.objects.all().size() == 1,"death creates exactly one finite corpse")
	if sim.objects.all().is_empty(): model.free(); quit(1); return
	var corpse = sim.objects.all()[0]
	for i in range(5): sim.tick(.1)
	check(sim.objects.all().size() == 1,"repeated ticks cannot duplicate corpse")
	check(corpse.providers[0].stock == 1,"one finite edible portion")
	var a = sim.spawn(Vector2.ZERO); a.body.nourishment = .1
	for i in range(30): sim.tick(.1)
	check(corpse.providers[0].stock == 1,"ordinary hunger rejects corpse")
	a.position = Vector2.ZERO; a.body.nourishment = 0; a.body.deprivation = .9
	var b = sim.spawn(Vector2(.1,0)); b.body.nourishment = 0; b.body.deprivation = .9
	a.personality.aggression = 0; b.personality.aggression = 0
	for i in range(25): sim.tick(.1)
	check(corpse.providers[0].stock == 0 and sim.objects.get_object(corpse.id) == null,"corpse depleted once and disappears")
	check((a.body.nourishment > .3) != (b.body.nourishment > .3),"only one consumer gains nourishment")
	model.free()
	for moved in [false,true]:
		model = WorldModel.new(); sim = model.simulation
		dead = sim.spawn(Vector2.ZERO); dead.body.damage(2); sim.tick(.1)
		corpse = sim.objects.all()[0]; a = sim.spawn(Vector2.ZERO)
		a.body.nourishment = 0; a.body.deprivation = .9; a.personality.aggression = 0
		sim.tick(.1)
		check(corpse.providers[0].has_user(a.id),"eligible consumer reserves corpse")
		if moved: sim.objects.move(corpse.id,Vector2(20,0))
		else: sim.objects.remove(corpse.id)
		for i in range(25): sim.tick(.1)
		check(a.body.nourishment == 0 and not corpse.providers[0].has_user(a.id),"invalidated corpse gives no nutrition or retained reservation")
		model.free()
	model = WorldModel.new(); sim = model.simulation; a = sim.spawn(Vector2.ZERO); sim.remove(a.id)
	sim.tick(.1); check(sim.objects.all().is_empty(),"editor deletion is not a death")
	model.free()
	print("corpse_resources: %d failures" % failures); quit(1 if failures else 0)
