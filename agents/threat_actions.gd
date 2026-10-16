class_name AgentThreatActions
extends RefCounted
static func eligible(agent: PolygonAgent,profile: EmergencyProfile) -> bool:
	return profile.predation_enabled and agent.body.deprivation >= profile.predation_deprivation and agent.body.nourishment < profile.predation_nourishment and float(agent.assessment.get("harm_rate",0)) > 0
static func candidates(agent: PolygonAgent,simulation: AgentSimulation) -> Array:
	var options: Array = []
	var active: Array = []
	for id in agent.threats.keys():
		if agent.threats[id].until <= simulation.time: agent.threats.erase(id)
		else: active.append(id)
	if not active.is_empty():
		var nearest: int = active[0]
		for id in active:
			if agent.position.distance_to(agent.threats[id].position) < agent.position.distance_to(agent.threats[nearest].position): nearest = id
		var threat: Vector2 = agent.threats[nearest].position
		var best: Dictionary = {}
		var best_gain := 0.0
		for i in range(8):
			var direction = (agent.position-threat).normalized()
			if direction == Vector2.ZERO: direction = Vector2.RIGHT
			var point = agent.position+direction.rotated(i*TAU/8)*3
			var gain = point.distance_to(threat)-agent.position.distance_to(threat)
			if gain <= best_gain: continue
			var route = simulation.navigation.route(agent.position,point,agent.radius)
			if route.status != &"OK": continue
			best_gain = gain
			best = {"kind":&"flee","key":"flee:%d" % nearest,"target":nearest,"position":point,"route_points":route.points,"route_revision":simulation.model.structures.traversal_revision,"score":1000.0,"urgent":true,"reason":"Escaping an immediate threat."}
		if not best.is_empty(): options.append(best)
		elif agent.agent_beliefs.has(nearest):
			options.append({"kind":&"defend","key":"defend:%d" % nearest,"target":nearest,"position":agent.agent_beliefs[nearest].position,"score":1000.0,"urgent":true,"reason":"No escape route; defending against an attacker."})
		return options
	var profile = simulation.profile()
	if agent.timely_food or agent.ordinary_food_unchecked or not eligible(agent,profile) or agent.personality.aggression <= 0: return options
	var count := 0
	for id in agent.agent_beliefs:
		var belief: Dictionary = agent.agent_beliefs[id]
		if simulation.time-belief.observed_at > 3 or simulation.time < float(agent.prey_retry.get(id,0)): continue
		if count >= 4: break
		count += 1
		var distance = agent.position.distance_to(belief.position)
		var risk = float(belief.condition)*agent.personality.caution*30
		var score = agent.personality.aggression*60-risk-distance*2
		if score <= 20: continue
		var route = simulation.navigation.route(agent.position,belief.position,agent.radius)
		if route.status != &"OK": agent.prey_retry[id] = simulation.time+3; continue
		options.append({"kind":&"pursue","key":"pursue:%d" % id,"target":id,"position":belief.position,"route_points":route.points,"route_revision":simulation.model.structures.traversal_revision,"score":score,"urgent":true,"reason":"Extreme deprivation: attempting predation despite the risk."})
	return options
static func tick(agent: PolygonAgent,simulation: AgentSimulation,delta: float) -> void:
	var control = agent.controller
	var target_id = int(control.current.get("target",0))
	if control.current.kind == &"flee":
		agent.action = &"fleeing"
		if not control._move(agent,simulation.navigation,delta): control.cancel(agent)
		return
	var belief: Dictionary = agent.agent_beliefs.get(target_id,{})
	if belief.is_empty(): control.cancel(agent); return
	var location: Vector2 = belief.position
	if simulation.time-float(belief.observed_at) > 3:
		agent.prey_retry[target_id] = simulation.time+3; control.cancel(agent); return
	var visible_now = float(belief.observed_at) == simulation.time
	if agent.position.distance_to(location) <= agent.radius+float(belief.radius)+simulation.profile().contact_margin:
		if visible_now:
			agent.action = &"defending" if control.current.kind == &"defend" else &"attacking"
			simulation.combat.queue_strike(agent.id,target_id,control.current.kind == &"pursue")
		else:
			agent.remember_event("Lost sight of target; searching its last observed location.")
			if control.route_points.is_empty():
				var point = location+Vector2.from_angle(agent.id+simulation.time)*.5
				var route = simulation.navigation.route(agent.position,point,agent.radius)
				if route.status == &"OK": control.route_points = route.points
			control._move(agent,simulation.navigation,delta)
		return
	if control.route_points.is_empty() or control.route_revision != simulation.model.structures.traversal_revision or control.current.position != location:
		var route = simulation.navigation.route(agent.position,location,agent.radius)
		if route.status != &"OK":
			agent.prey_retry[target_id] = simulation.time+3; control.cancel(agent); return
		control.route_points = route.points; control.route_revision = simulation.model.structures.traversal_revision; control.current.position = location
	agent.action = &"defending" if control.current.kind == &"defend" else &"pursuing"
	if not control._move(agent,simulation.navigation,delta): control.cancel(agent)
