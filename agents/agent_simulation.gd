class_name AgentSimulation
extends RefCounted
var model: WorldModel
var objects := WorldObjectStore.new()
var agents: Array[PolygonAgent] = []
var navigation: AgentNavigation
var time := 0.0
var _next_id := 1
func _init(world: WorldModel = null) -> void:
	model = world
	if world != null: navigation = AgentNavigation.new(world)
func spawn(point: Vector2) -> PolygonAgent:
	if not StructureData.in_range(point) or model.physical.sweep(point,point,0.2).hit: return null
	var agent = PolygonAgent.new()
	agent.id = _next_id; _next_id += 1
	agent.position = point
	agent.motion.begin(point,agent.facing)
	agent.controller = AgentActionController.new()
	agents.append(agent)
	return agent
func remove(id: int) -> void:
	for agent in agents:
		if agent.id == id:
			agent.controller.cancel(agent); agents.erase(agent); return
func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	time += delta
	for agent in agents:
		agent.motion.begin(agent.position,agent.facing)
		agent.body.tick(delta)
		if not agent.body.alive():
			agent.controller.cancel(agent); agent.action = &"dead"; continue
		if time >= agent.next_perception:
			AgentPerception.observe(agent,objects,model,time)
			agent.next_perception = time + 0.25
		if time >= agent.next_decision:
			agent.decision_scores = AgentDecision.candidates(agent,time,model.structures.traversal_revision)
			agent.controller.reconsider(agent,agent.decision_scores,time)
			agent.next_decision = time + 0.5
		agent.controller.tick(agent,self,delta)
	objects.remove_depleted()
func occupied(capsule: Dictionary) -> bool:
	var path: PackedVector2Array = capsule.path
	for agent in agents:
		for i in range(path.size()-1):
			if is_finite(PhysicalQueries.capsule_time(agent.position,agent.position,path[i],path[i+1],agent.radius+capsule.radius)): return true
	return false
