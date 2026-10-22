extends SceneTree
var failures := 0
class DelayedNavigation extends AgentNavigation:
	func route(from: Vector2,to: Vector2,_radius: float) -> Dictionary:
		if from.distance_to(to)>2: return {"status":&"DEFERRED","points":[]}
		return {"status":&"OK","points":[to]}
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var script=load("res://agents/spatial_index.gd")
	if script==null: quit(1); return
	var index=script.new(); var items: Array=[]
	var rng=RandomNumberGenerator.new(); rng.seed=12
	for i in range(200): items.append({"id":i+1,"position":Vector2(rng.randf_range(-100,100),rng.randf_range(-100,100))})
	index.rebuild(items)
	for i in range(100):
		var point=Vector2(rng.randf_range(-100,100),rng.randf_range(-100,100)); var radius=rng.randf_range(0,40)
		var expected=items.filter(func(item): return item.position.distance_squared_to(point)<=radius*radius)
		check(index.query(point,radius)==expected,"spatial candidates equal stable-ID brute-force oracle")
	check(index.query(Vector2.ZERO,1e8).size()==200 and index.query(Vector2.ZERO,-1).is_empty(),"extreme query radii remain bounded and valid")
	var world=WorldModel.new(); var nav=world.simulation.navigation
	world.execute(StructureCommand.wall(Vector2(2,-2),Vector2(2,2),false))
	nav.begin_tick(0,1)
	var route=nav.route(Vector2.ZERO,Vector2(4,0),.2)
	check(route.status==&"DEFERRED" and nav.expansions_this_tick<=1,"global work exhaustion is deferred, not impossible")
	nav.begin_tick(1,8192); route=nav.route(Vector2.ZERO,Vector2(4,0),.2)
	check(route.status==&"OK","deferred routes can complete with later budget")
	var work=nav.expansions_this_tick; route.points.clear()
	var again=nav.route(Vector2.ZERO,Vector2(4,0),.2)
	check(again.status==&"OK" and not again.points.is_empty() and nav.expansions_this_tick==work,"cached routes avoid work and protect stored points from mutation")
	world.execute(StructureCommand.wall(Vector2(2,-2),Vector2(2,2),true))
	check(nav.route(Vector2.ZERO,Vector2(4,0),.2).points.size()==1,"geometry changes invalidate cached detours")
	world.free()
	world=WorldModel.new(); var observer=world.simulation.spawn(Vector2.ZERO)
	var other=world.simulation.spawn(Vector2(1,0))
	world.simulation.objects.add(load("res://objects/definitions/food.tres"),Vector2(0,1))
	AgentPerception.observe(observer,world.simulation.objects,world,0)
	AgentPerception.observe_agents(observer,world.simulation.agents,world,0)
	var resources=observer.beliefs.duplicate(true); var people=observer.agent_beliefs.duplicate(true)
	var frame={"sight":{},"people":{},"resources":{}}
	AgentPerception.observe(observer,world.simulation.objects,world,0,null,frame)
	AgentPerception.observe_agents(observer,world.simulation.agents,world,0,frame)
	check(observer.beliefs==resources and observer.agent_beliefs==people,"shared perception frame matches uncached observations")
	AgentPerception.observe(other,world.simulation.objects,world,0,null,frame)
	AgentPerception.observe_agents(other,world.simulation.agents,world,0,frame)
	observer.beliefs.values()[0].effects[&"nourishment"]=999
	check(other.beliefs.values()[0].effects[&"nourishment"]!=999,"observers own independent resource snapshots")
	check(not frame.sight.is_empty(),"perception shares physical sight results within one immutable observation phase")
	world.free()
	world=WorldModel.new(); var explorer=world.simulation.spawn(Vector2.ZERO)
	var short_search=explorer.exploration.choose(explorer,DelayedNavigation.new(world))
	check(not short_search.get("constrained",false),"a short route after deferred long probes is not evidence of confinement")
	world.free()
	world=WorldModel.new(); var sim=world.simulation; var a=sim.spawn(Vector2.ZERO)
	a.body.nourishment=0; a.body.deprivation=.8; a.personality.aggression=1
	sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(4,0))
	AgentPerception.observe(a,sim.objects,world,0)
	world.execute(StructureCommand.wall(Vector2(2,-2),Vector2(2,2),false))
	a.assessment=EmergencyAssessment.evaluate(a.body,sim._profile)
	nav=sim.navigation; nav.begin_tick(0,0)
	var options=AgentDecision.candidates(a,0,world.structures.traversal_revision,sim)
	check(a.ordinary_food_unchecked and a.last_setback_at==-INF,"budget delay neither disproves food nor reports a setback")
	check(a.memory.episodes.is_empty(),"budget delay creates no negative autobiographical evidence")
	check(options.all(func(o): return o.kind!=&"pursue" and o.kind!=&"contest_food"),"unassessed ordinary food suppresses desperate competition")
	world.free()
	# Exactly coincident global/per-route limits still mean incomplete computation.
	for work_budget in [4096,8192]:
		world=WorldModel.new(); sim=world.simulation; a=sim.spawn(Vector2.ZERO); a.sight_range=200
		a.body.nourishment=0; a.body.deprivation=.8; a.personality.aggression=1
		sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(100,0))
		AgentPerception.observe(a,sim.objects,world,0)
		world.execute(StructureCommand.wall(Vector2(50,-100),Vector2(50,100),false))
		a.assessment=EmergencyAssessment.evaluate(a.body,sim._profile)
		sim.navigation.begin_tick(0,work_budget)
		AgentDecision.candidates(a,0,world.structures.traversal_revision,sim)
		check(a.ordinary_food_unchecked and a.last_setback_at==-INF and a.beliefs.values()[0].retry_at==0,"neither global nor per-route search limits are negative evidence")
		world.free()
	world=WorldModel.new(); sim=world.simulation; a=sim.spawn(Vector2.ZERO); a.sight_range=1000
	for i in range(150): sim.objects.add(load("res://objects/definitions/food.tres"),Vector2(i,2))
	AgentPerception.observe(a,sim.objects,world,0)
	check(a.beliefs.size()<=64,"resource snapshots remain bounded")
	world.free()
	print("history_work_budget: %d failures" % failures); quit(1 if failures else 0)
