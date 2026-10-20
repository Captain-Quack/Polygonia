extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	if not ResourceLoader.exists("res://agents/gore_effects.gd"):
		check(false,"bounded gore presentation exists"); quit(1); return
	var effects = load("res://agents/gore_effects.gd").new()
	effects.hit(1,Vector2.ZERO,Vector2.RIGHT,.1)
	check(not effects.particles.is_empty() and not effects.stains.is_empty(),"hits emit spray and a ground stain")
	check(effects.appearance(1).flash > 0,"damage produces immediate hit feedback")
	var before = effects.particles.size()
	effects.death(1,Vector2.ZERO,true)
	check(effects.particles.size() > before,"traumatic death emits a larger burst and fragments")
	var count = effects.stains.size()
	for i in range(20): effects.advance(.1)
	check(effects.particles.is_empty() and effects.stains.size() >= count,"airborne fragments settle while stains remain")
	for i in range(1000): effects.hit(i+1,Vector2(i*.2,0),Vector2.RIGHT,.1)
	check(effects.particles.size() <= effects.MAX_PARTICLES,"particle storage is capped during sustained violence")
	check(effects.stains.size() <= effects.MAX_STAINS,"stain storage is capped")
	check(effects.actor_count() <= effects.MAX_ACTORS,"actor feedback storage is capped")
	for stain in effects.stains:
		check(stain.radius <= .45 and stain.opacity <= .55,"ground effects stay local and translucent")
	effects.advance(200)
	check(effects.stains.is_empty() and effects.actor_count() == 0,"old effects expire")
	effects.enabled = false; effects.hit(1,Vector2.ZERO,Vector2.RIGHT,.1)
	check(effects.particles.is_empty() and effects.stains.is_empty(),"disabled effects produce no visual work")
	var model = WorldModel.new(); var sim = model.simulation
	var a = sim.spawn(Vector2.ZERO); var b = sim.spawn(Vector2(.3,0))
	b.body.health = .05
	sim.combat.queue_strike(a.id,b.id,false); sim.combat.resolve(sim); sim.tick(.1)
	check(not sim.gore.particles.is_empty() and b.death_handled,"real contact damage and death drive effects")
	var corpses = sim.objects.all()
	if corpses.is_empty(): model.free(); quit(1); return
	a.body.nourishment = 0; a.body.deprivation = .9; a.personality.aggression = 0
	for i in range(10): sim.tick(.1)
	check(sim.gore.appearance(a.id).blood > 0,"corpse feeding visibly stains the eater")
	check(corpses[0].providers[0].stock == 1,"visual bites do not consume an incomplete meal")
	model.free()
	var outcomes: Array = []
	for enabled in [false,true]:
		model = WorldModel.new(); sim = model.simulation; sim.gore.enabled = enabled
		a = sim.spawn(Vector2.ZERO); b = sim.spawn(Vector2(.3,0))
		a.body.nourishment = 0; a.body.deprivation = .9; a.personality.aggression = 1; a.personality.caution = 0
		for i in range(50): sim.tick(.1)
		outcomes.append([a.position,b.position,a.body.health,b.body.health,a.body.nourishment,b.body.nourishment,a.action,b.action])
		model.free()
	check(outcomes[0] == outcomes[1],"cosmetic RNG and effects do not change behavior or outcomes")
	print("gore_effects: %d failures" % failures); quit(1 if failures else 0)
