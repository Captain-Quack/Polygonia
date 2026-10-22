class_name AgentSimulation
extends RefCounted
var model: WorldModel
var objects := WorldObjectStore.new()
var agents: Array[PolygonAgent] = []
var navigation: AgentNavigation
var time := 0.0
var seed_value := 1
var route_expansion_budget := 8192
var _by_id: Dictionary = {}
var _agent_index := AgentSpatialIndex.new()
var _object_index := AgentSpatialIndex.new()
var _agents_dirty := true
var _object_revision := -1
var _decision_start := 0
var _max_sight := 0.0
func _refresh_agents() -> void:
	_agent_index.rebuild(agents); _agents_dirty=false; _max_sight=0.0
	for agent in agents:
		if is_finite(agent.sight_range): _max_sight=maxf(_max_sight,agent.sight_range)
func nearby_agents(point: Vector2,radius: float) -> Array:
	if _agents_dirty: _refresh_agents()
	return _agent_index.query(point,radius)
func possible_witnesses(point: Vector2) -> Array:
	if _agents_dirty: _refresh_agents()
	return _agent_index.query(point,_max_sight)
func nearby_objects(point: Vector2,radius: float) -> Array:
	if _object_revision!=objects.revision:
		_object_index.rebuild(objects.all()); _object_revision=objects.revision
	return _object_index.query(point,radius)
# Internal systems read this shared configuration without mutating it.
# External callers receive a defensive copy through profile().
var _profile := EmergencyProfile.new()
func configure(profile: EmergencyProfile) -> bool:
	if profile == null or not profile.validate().is_empty(): return false
	_profile = profile.duplicate(true)
	return true
func profile() -> EmergencyProfile:
	return _profile.duplicate(true)
var _next_id := 1
func _init(world: WorldModel = null) -> void:
	model = world
	if world != null: navigation = AgentNavigation.new(world)
func spawn(point: Vector2) -> PolygonAgent:
	if not StructureData.in_range(point) or model.physical.sweep(point,point,0.2).hit: return null
	var agent = PolygonAgent.new()
	agent.id = _next_id; _next_id += 1
	agent.personality = AgentPersonality.from_seed(seed_value,agent.id)
	agent.position = point
	agent.exploration.initialize(seed_value,agent.id,point)
	agent.motion.begin(point,agent.facing)
	agent.controller = AgentActionController.new()
	agents.append(agent)
	_by_id[agent.id]=agent; _agents_dirty=true
	agent.next_cognition=time+fmod(agent.id*.137,1.0)
	return agent
func remove(id: int) -> void:
	for agent in agents:
		if agent.id == id:
			agent.controller.cancel(agent); combat.forget(id); gore.remove_actor(id); agents.erase(agent); _by_id.erase(id); _agents_dirty=true; return
var combat := AgentCombatSystem.new()
var gore := AgentGoreEffects.new()
func get_agent(id: int) -> PolygonAgent:
	return _by_id.get(id)
func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	time += delta
	navigation.begin_tick(time,route_expansion_budget)
	_agents_dirty=true
	gore.advance(delta)
	for agent in agents:
		agent.memory.time = time
		agent.motion.begin(agent.position,agent.facing)
		agent.body.tick_deprivation(delta,_profile)
		agent.body.tick(delta)
		agent.assessment = EmergencyAssessment.evaluate(agent.body,_profile)
		EmergencyAssessment.update_context(agent,time,delta,_profile)
		if not agent.body.alive():
			AgentDeathSystem.materialize(agent,self)
	# Perception of intentions happens before any agent changes its decision.
	# This shared frame dies before sharing, movement, admissions or door changes.
	var perception_frame={"sight":{},"people":{},"resources":{}}
	for agent in agents:
		if not agent.body.alive(): continue
		AgentPerception.observe_agents(agent,nearby_agents(agent.position,agent.sight_range),model,time,perception_frame)
		var urgent = (agent.assessment.urgency > 0 and agent.assessment.harm_rate > 0) or AgentThreatActions.eligible(agent,_profile) or not agent.threats.is_empty()
		if time >= agent.next_perception or urgent:
			AgentPerception.observe(agent,objects,model,time,nearby_objects(agent.position,agent.sight_range),perception_frame)
			agent.next_perception = time+.25
		AgentCognition.observe(agent,self)
	AgentFoodSocial.share(self)
	# Rotating first opportunity prevents permanent priority by spawn order.
	for offset in range(agents.size()):
		var agent=agents[(_decision_start+offset)%agents.size()]
		if not agent.body.alive(): continue
		var urgent = (agent.assessment.urgency > 0 and agent.assessment.harm_rate > 0) or AgentThreatActions.eligible(agent,_profile) or not agent.threats.is_empty()
		if time >= agent.next_decision or urgent:
			agent.decision_scores = AgentDecision.candidates(agent,time,model.structures.traversal_revision,self)
			agent.controller.reconsider(agent,agent.decision_scores,time,urgent)
			agent.next_decision = time+.5
	_decision_start=(_decision_start+1)%maxi(1,agents.size())
	for agent in agents:
		if agent.body.alive(): agent.controller.tick(agent,self,delta)
	_agents_dirty=true
	combat.resolve(self)
	for agent in agents:
		if not agent.body.alive(): AgentDeathSystem.materialize(agent,self)
		else: gore.follow(agent)
	objects.remove_depleted()
func occupied(capsule: Dictionary) -> bool:
	var path: PackedVector2Array = capsule.path
	for agent in agents:
		if agent.death_handled: continue
		for i in range(path.size()-1):
			if is_finite(PhysicalQueries.capsule_time(agent.position,agent.position,path[i],path[i+1],agent.radius+capsule.radius)): return true
	return false

