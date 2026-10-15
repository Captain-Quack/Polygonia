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
