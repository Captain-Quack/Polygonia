class_name AgentPerception
extends RefCounted
static func visible(agent: PolygonAgent,point: Vector2,model: WorldModel) -> bool:
	return agent.position.distance_to(point) <= agent.sight_range and model.physical.visibility_hits(agent.position,point).is_empty()
static func observe(agent: PolygonAgent,objects: WorldObjectStore,model: WorldModel,now: float) -> void:
	var seen: Dictionary = {}
	for object in objects.all():
		if not visible(agent,object.position,model): continue
		seen[object.id] = true
		for index in range(object.providers.size()):
			var key = "%d:%d" % [object.id,index]
			var previous: Dictionary = agent.beliefs.get(key,{})
			var observation = object.providers[index].observation()
			if object.providers[index].has_user(agent.id): observation.available = true
			observation.merge({"key":key,"source":object.id,"provider":index,
				"position":object.position,"observed_at":now,"revision":object.revision,
				"retry_at":previous.get("retry_at",0.0),"failed_revision":previous.get("failed_revision",-1)})
			if previous.get("position",object.position) != object.position: observation.retry_at = 0.0
			agent.beliefs[key] = observation
	for key in agent.beliefs.keys():
		var belief = agent.beliefs[key]
		if not seen.has(belief.source) and visible(agent,belief.position,model):
			agent.beliefs.erase(key)
			agent.remember_event("The remembered resource is no longer here.")

static func agent_snapshot(other: PolygonAgent,now: float) -> Dictionary:
	return {"position":other.position,"observed_at":now,"radius":other.radius,"condition":ceilf(other.body.health*3)/3.0}
static func observe_agents(agent: PolygonAgent,agents: Array[PolygonAgent],model: WorldModel,now: float) -> void:
	var seen: Dictionary = {}
	for other in agents:
		if other == agent or not other.body.alive() or not visible(agent,other.position,model): continue
		seen[other.id] = true
		agent.agent_beliefs[other.id] = agent_snapshot(other,now)
		if other.controller.current.get("target",0) == agent.id and other.controller.current.get("kind") in [&"pursue",&"defend"]:
			agent.threats[other.id] = {"position":other.position,"until":now+3.0}
		elif agent.threats.has(other.id): agent.threats[other.id].position = other.position
	for id in agent.agent_beliefs.keys():
		var belief: Dictionary = agent.agent_beliefs[id]
		if not seen.has(id) and (now-belief.observed_at>3 or visible(agent,belief.position,model)):
			agent.agent_beliefs.erase(id)
