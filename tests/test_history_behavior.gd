extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func prepared():
	var world = WorldModel.new(); world.simulation.time=100
	var a=world.simulation.spawn(Vector2.ZERO)
	a.body.nourishment=.45; a.body.fatigue=.1; a.body.hunger_rate=0; a.body.fatigue_rate=0
	a.personality.caution=.8; a.personality.persistence=.5
	for p in [Vector2(-3,0),Vector2(3,0)]: world.simulation.objects.add(load("res://objects/definitions/food.tres"),p)
	AgentPerception.observe(a,world.simulation.objects,world,100)
	return world
func best(world):
	return AgentDecision.candidates(world.simulation.agents[0],world.simulation.time,world.structures.traversal_revision,world.simulation)[0]
func train(a,unsafe: Vector2,safe: Vector2):
	for i in range(5):
		a.memory.record(&"attacked",unsafe,10+i*12,8)
		a.memory.record(&"meal",safe,10+i*12,0,2,.3,false,.3)
func _initialize() -> void:
	var w1=prepared(); var a=w1.simulation.agents[0]
	if a.get("memory")==null: check(false,"agents require personal history"); w1.free(); quit(1); return
	var w2=prepared(); var b=w2.simulation.agents[0]
	train(a,Vector2(-3,0),Vector2(3,0)); train(b,Vector2(3,0),Vector2(-3,0))
	check(best(w1).position==Vector2(3,0) and best(w2).position==Vector2(-3,0),"identical present worlds choose different food because of history")
	var ma=a.memory.snapshot(100); var mb=b.memory.snapshot(100)
	a.memory.restore(mb,100); b.memory.restore(ma,100)
	check(best(w1).position==Vector2(-3,0) and best(w2).position==Vector2(3,0),"swapping memories swaps preference")
	a.memory=AgentExperienceMemory.new(); b.memory=AgentExperienceMemory.new()
	check(best(w1).position==best(w2).position,"ablating history restores identical choice")
	train(a,Vector2(-3,0),Vector2(3,0))
	check("remember" in best(w1).reason.to_lower() or "experience" in best(w1).reason.to_lower(),"decision explains an actual memory influence")
	w1.execute(StructureCommand.wall(Vector2(10,10),Vector2(12,10),false))
	check(a.memory.place(Vector2(-3,0),100).danger>.5,"topology edits do not erase place history")
	w1.free(); w2.free()
	# Actual completed meal creates outcome evidence; cancellation does not.
	var world=WorldModel.new(); var sim=world.simulation; a=sim.spawn(Vector2.ZERO)
	a.body.nourishment=.4; a.personality.kindness=0
	var food=sim.objects.add(load("res://objects/definitions/food.tres"),a.position)
	for i in range(25): sim.tick(.1)
	check(a.memory.place(a.position,sim.time).food>0 and a.memory.habit(&"eat",a.position,sim.time).success>.5,"completed meal learns relief and reliability")
	world.free()
	world=WorldModel.new(); sim=world.simulation; a=sim.spawn(Vector2.ZERO)
	a.body.nourishment=.4; food=sim.objects.add(load("res://objects/definitions/food.tres"),a.position)
	sim.tick(.1); a.controller.cancel(a)
	check(a.memory.place(a.position,sim.time).food==0,"interrupted meal does not teach successful feeding")
	world.free()
	# Actual visible combat teaches victim and witness; an occluded bystander learns nothing.
	world=WorldModel.new(); sim=world.simulation; a=sim.spawn(Vector2.ZERO); b=sim.spawn(Vector2(.4,0))
	var witness=sim.spawn(Vector2(0,2)); var hidden=sim.spawn(Vector2(5,0))
	world.execute(StructureCommand.wall(Vector2(3,-5),Vector2(3,5),false))
	sim.combat.queue_strike(a.id,b.id,false); sim.combat.resolve(sim)
	check(b.memory.person(a.id,0).harm>0,"victim remembers actual attacker")
	check(witness.memory.person(a.id,0).harm>0 and hidden.memory.person(a.id,0).harm==0,"only visible witnesses learn the event")
	check(witness.memory.person(b.id,0).harm==0,"witness does not blame the victim")
	world.free()
	world=WorldModel.new(); sim=world.simulation; a=sim.spawn(Vector2.ZERO)
	a.body.nourishment=.5; a.personality.kindness=1
	food=sim.objects.add(load("res://objects/definitions/food.tres"),a.position); sim.tick(.1)
	b=sim.spawn(Vector2(.35,0)); b.body.nourishment=.1; b.personality.aggression=0
	sim.tick(.1)
	check(b.memory.person(a.id,sim.time).help>0,"actual donation teaches recipient who helped")
	check(a.controller.current.get("expected_effects",{})==a.controller.provider.meal_effects(),"a deliberate gift updates expected own relief rather than teaching disappointment")
	var willingness=AgentCognition.willingness(a,b.id,sim.time)
	a.memory.record(&"attacked",a.position,sim.time,b.id)
	check(AgentCognition.willingness(a,b.id,sim.time)<willingness and a.personality.kindness==1,"harm changes trust without rewriting kindness")
	world.free()
	# Safe, familiar waypoint supplies an actual alternative around remembered danger.
	world=WorldModel.new(); sim=world.simulation; a=sim.spawn(Vector2(.5,.5)); a.personality.caution=1
	for i in range(5):
		a.memory.record(&"attacked",Vector2(2.5,.5),i*12,9)
		a.memory.visit(Vector2(2,-2),i*12,true)
	sim.time=60
	var route=AgentCognition.route(a,{"key":"test","position":Vector2(5,.5)},sim)
	check(route.get("detour",false) and route.points.size()>1,"history can change the route to an unchanged destination")
	var destination=Vector2(5,.5)
	a.controller.current={"kind":&"interact","key":"test","position":destination}
	a.controller.route_points=[destination]; a.controller.route_revision=world.structures.traversal_revision
	a.controller.progress=.75
	a.controller.reconsider(a,[{"kind":&"interact","key":"test","position":destination,"score":1.0,"route_points":route.points,"route_revision":world.structures.traversal_revision}],sim.time)
	check(a.controller.route_points==route.points and a.controller.progress==.75,"reconsidering the same destination adopts its safer route without restarting progress")
	var before_y=a.position.y
	a.controller._move(a,sim.navigation,.1)
	check(a.position.y<before_y,"actual movement follows the revised safe waypoint")
	world.free()
	world=prepared(); sim=world.simulation; a=sim.agents[0]
	for i in range(5):
		a.memory.record(&"meal",Vector2(-3,0),10+i*12,0,10,.1,false,.8)
		a.memory.record(&"meal",Vector2(3,0),10+i*12,0,11,.1,false,.1)
	check(best(world).position==Vector2(3,0),"repeatedly disappointing relief changes preference even when both actions complete")
	world.free()
	world=prepared(); sim=world.simulation; a=sim.agents[0]
	# Harm happened elsewhere; fear can follow a currently observed individual.
	a.memory.record(&"attacked",Vector2(40,40),90,7)
	a.agent_beliefs[7]={"position":Vector2(-3,0),"observed_at":100,"radius":.2,"condition":1.0,"hunger":0.0}
	check(best(world).position==Vector2(3,0),"known harmful individual influences approach in a new place")
	world.free()
	# A remembered successful location can guide search after the object disappears unseen.
	world=prepared(); sim=world.simulation; a=sim.agents[0]
	train(a,Vector2(-3,0),Vector2(3,0))
	var choice=best(world).position
	var saved=JSON.parse_string(JSON.stringify(a.memory.snapshot(100)))
	a.memory=AgentExperienceMemory.new(); sim.time=5000
	check(a.memory.restore(saved,sim.time),"saved evidence restores with a different clock")
	AgentPerception.observe(a,sim.objects,world,sim.time)
	check(best(world).position==choice,"rebased JSON history preserves the actual choice")
	for i in range(100):
		a.memory.visit(Vector2(-3,0),5001+i,true)
		if i%10==0: a.memory.record(&"meal",Vector2(-3,0),5001+i,0,1,.3,false,.3)
	sim.time=5101
	check(best(world).position==Vector2(-3,0),"safe revisits and successful meals can reverse an acquired avoidance")
	world.free()
	world=WorldModel.new(); sim=world.simulation; a=sim.spawn(Vector2.ZERO)
	a.body.nourishment=.35; a.memory.record(&"meal",Vector2(8,0),0,0,40,.3)
	var search=a.exploration.choose(a,sim.navigation)
	check(not search.is_empty() and search.get("remembered",false),"exploration can revisit a remembered food location")
	world.free()
	print("history_behavior: %d failures" % failures); quit(1 if failures else 0)
