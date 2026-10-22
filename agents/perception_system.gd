class_name AgentPerception
extends RefCounted
static func visible(agent: PolygonAgent,point: Vector2,model: WorldModel,frame: Dictionary = {}) -> bool:
	if not (agent.sight_range >= 0 and agent.position.distance_squared_to(point) <= agent.sight_range*agent.sight_range): return false
	if frame.is_empty(): return model.physical.has_line_of_sight(agent.position,point)
	var from=agent.position; var to=point
	if from.x>to.x or (from.x==to.x and from.y>to.y): from=point; to=agent.position
	var key=Vector4(from.x,from.y,to.x,to.y)
	if frame.sight.has(key): return frame.sight[key]
	# Cull distant barriers once per observer, before testing its many sight rays.
	if not frame.has("barriers"): frame.barriers={}
	var observer_key=Vector3(agent.position.x,agent.position.y,agent.sight_range)
	if not frame.barriers.has(observer_key) and frame.barriers.size()<2048:
		frame.barriers[observer_key]=model.physical._sight_segments(agent.position,agent.sight_range)
	var clear=PhysicalQueries.sight_in_segments(from,to,frame.barriers[observer_key]) if frame.barriers.has(observer_key) else model.physical.has_line_of_sight(from,to)
	if frame.sight.size()<8192: frame.sight[key]=clear
	return clear
## Optional frame is owned by one immutable simulation perception phase, then discarded.
static func observe(agent: PolygonAgent,objects: WorldObjectStore,model: WorldModel,now: float,candidates: Variant = null,frame: Dictionary = {}) -> void:
	var seen: Dictionary = {}
	for object in objects.all() if candidates==null else candidates:
		if not visible(agent,object.position,model,frame): continue
		seen[object.id] = true
		for index in range(object.providers.size()):
			var key = "%d:%d" % [object.id,index]
			var previous: Dictionary = agent.beliefs.get(key,{})
			var observation: Dictionary
			if frame.is_empty(): observation=object.providers[index].observation()
			else:
				if not frame.resources.has(key) and frame.resources.size()<2048: frame.resources[key]=object.providers[index].observation()
				observation=frame.resources[key].duplicate(true) if frame.resources.has(key) else object.providers[index].observation()
			if object.providers[index].has_user(agent.id): observation.available = true
			observation.merge({"key":key,"source":object.id,"provider":index,
				"position":object.position,"observed_at":now,"revision":object.revision,
				"retry_at":previous.get("retry_at",0.0),"failed_revision":previous.get("failed_revision",-1)})
			if previous.get("position",object.position) != object.position: observation.retry_at = 0.0
			agent.beliefs[key] = observation
	for key in agent.beliefs.keys():
		var belief = agent.beliefs[key]
		if not seen.has(belief.source) and visible(agent,belief.position,model,frame):
			if belief.interaction==&"eat": agent.memory.record(&"missing",belief.position,now,0,belief.source)
			agent.beliefs.erase(key)
			agent.remember_event("The remembered resource is no longer here.")
	if agent.beliefs.size()>64:
		var keys=agent.beliefs.keys()
		var active=agent.controller.current.get("meal_key",agent.controller.current.get("key",""))
		keys.sort_custom(func(a,b):
			if a==b: return false
			if a==active: return true
			if b==active: return false
			var ba: Dictionary=agent.beliefs[a]; var bb: Dictionary=agent.beliefs[b]
			if ba.observed_at!=bb.observed_at: return ba.observed_at>bb.observed_at
			var da=agent.position.distance_squared_to(ba.position); var db=agent.position.distance_squared_to(bb.position)
			return da<db if da!=db else a<b)
		for key in keys.slice(64): agent.beliefs.erase(key)
	for key in agent.familiarity.keys():
		if not agent.beliefs.has(key): agent.familiarity.erase(key)

static func agent_snapshot(other: PolygonAgent,now: float) -> Dictionary:
	return {"position":other.position,"observed_at":now,"radius":other.radius,"condition":ceilf(other.body.health*3)/3.0,"hunger":floorf(other.body.hunger()*3)/3.0}
static func observe_agents(agent: PolygonAgent,agents: Array,model: WorldModel,now: float,frame: Dictionary = {}) -> void:
	var seen: Dictionary = {}
	for other in agents:
		if other == agent or not visible(agent,other.position,model,frame): continue
		if not other.body.alive():
			agent.agent_beliefs.erase(other.id); agent.threats.erase(other.id); continue
		seen[other.id] = true
		if frame.is_empty(): agent.agent_beliefs[other.id]=agent_snapshot(other,now)
		else:
			if not frame.people.has(other.id) and frame.people.size()<2048: frame.people[other.id]=agent_snapshot(other,now)
			agent.agent_beliefs[other.id]=frame.people[other.id].duplicate() if frame.people.has(other.id) else agent_snapshot(other,now)
		if other.controller.current.get("target",0) == agent.id and other.controller.current.get("kind") in [&"pursue",&"contest_food"]:
			agent.threats[other.id] = {"position":other.position,"until":now+3.0}
		elif agent.threats.has(other.id): agent.threats[other.id].position = other.position
	for id in agent.agent_beliefs.keys():
		var belief: Dictionary = agent.agent_beliefs[id]
		if not seen.has(id) and (now-belief.observed_at>3 or visible(agent,belief.position,model,frame)):
			agent.agent_beliefs.erase(id)
	for id in agent.prey_retry.keys():
		if agent.prey_retry[id]<=now: agent.prey_retry.erase(id)

