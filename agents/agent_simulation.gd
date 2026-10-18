class_name AgentSimulation
extends RefCounted
var model: WorldModel
var objects := WorldObjectStore.new()
var agents: Array[PolygonAgent] = []
var navigation: AgentNavigation
var time := 0.0
var seed_value := 1
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
	return agent
func remove(id: int) -> void:
	for agent in agents:
		if agent.id == id:
			agent.controller.cancel(agent); combat.forget(id); agents.erase(agent); return
var combat := AgentCombatSystem.new()
func get_agent(id: int) -> PolygonAgent:
	for agent in agents:
		if agent.id == id: return agent
	return null
func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	time += delta
	for agent in agents:
		agent.motion.begin(agent.position,agent.facing)
		agent.body.tick_deprivation(delta,_profile)
		agent.body.tick(delta)
		agent.assessment = EmergencyAssessment.evaluate(agent.body,_profile)
		EmergencyAssessment.update_context(agent,time,delta,_profile)
		if not agent.body.alive():
			AgentDeathSystem.materialize(agent,self)
	# Perception of intentions happens before any agent changes its decision.
	for agent in agents:
		if not agent.body.alive(): continue
		AgentPerception.observe_agents(agent,agents,model,time)
		var urgent = (agent.assessment.urgency > 0 and agent.assessment.harm_rate > 0) or AgentThreatActions.eligible(agent,_profile) or not agent.threats.is_empty()
		if time >= agent.next_perception or urgent:
			AgentPerception.observe(agent,objects,model,time)
			agent.next_perception = time+.25
	for agent in agents:
		if not agent.body.alive(): continue
		var urgent = (agent.assessment.urgency > 0 and agent.assessment.harm_rate > 0) or AgentThreatActions.eligible(agent,_profile) or not agent.threats.is_empty()
		if time >= agent.next_decision or urgent:
			agent.decision_scores = AgentDecision.candidates(agent,time,model.structures.traversal_revision,self)
			agent.controller.reconsider(agent,agent.decision_scores,time,urgent)
			agent.next_decision = time+.5
	for agent in agents:
		if agent.body.alive(): agent.controller.tick(agent,self,delta)
	combat.resolve(self)
	for agent in agents:
		if not agent.body.alive(): AgentDeathSystem.materialize(agent,self)
	objects.remove_depleted()
func occupied(capsule: Dictionary) -> bool:
	var path: PackedVector2Array = capsule.path
	for agent in agents:
		if agent.death_handled: continue
		for i in range(path.size()-1):
			if is_finite(PhysicalQueries.capsule_time(agent.position,agent.position,path[i],path[i+1],agent.radius+capsule.radius)): return true
	return false
