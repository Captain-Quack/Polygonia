class_name AgentThreatActions
extends RefCounted
static func eligible(agent: PolygonAgent,profile: EmergencyProfile) -> bool:
	return agent.body.alive() and profile.predation_enabled and (agent.body.deprivation >= profile.predation_deprivation or agent.desperation >= profile.desperate_feeding_threshold) and agent.body.nourishment < profile.predation_nourishment and float(agent.assessment.get("harm_rate",0)) > 0
static func candidates(agent: PolygonAgent,simulation: AgentSimulation) -> Array:
	var options: Array = []
	var active: Array = []
	for id in agent.threats.keys():
		if agent.threats[id].until <= simulation.time: agent.threats.erase(id)
		else: active.append(id)
	if not active.is_empty(): return _responses(agent,simulation,active)
	var profile = simulation._profile
	if agent.timely_food or agent.ordinary_food_unchecked or not eligible(agent,profile) or agent.personality.aggression <= 0: return options
	var count := 0
	for id in agent.agent_beliefs:
		var belief: Dictionary = agent.agent_beliefs[id]
		if simulation.time-belief.observed_at > 3 or simulation.time < float(agent.prey_retry.get(id,0)): continue
		if count >= 4: break
		count += 1
		var distance = agent.position.distance_to(belief.position)
		var risk = float(belief.condition)*agent.personality.caution*30*(1-.5*agent.desperation)
		var score = agent.personality.aggression*(60+30*agent.desperation)-risk-distance*2
		if score <= 20: continue
		var route = simulation.navigation.route(agent.position,belief.position,agent.radius)
		if route.status != &"OK": agent.prey_retry[id] = simulation.time+3; continue
		options.append({"kind":&"pursue","key":"pursue:%d" % id,"target":id,"position":belief.position,"route_points":route.points,"route_revision":simulation.model.structures.traversal_revision,"score":score,"urgent":true,"reason":"Desperate for nourishment: accepting the risk of predation."})
	return options
static func _responses(agent: PolygonAgent,simulation: AgentSimulation,active: Array) -> Array:
	var nearest: int = active[0]
	var enemy_strength := 0.0
	for id in active:
		var belief: Dictionary = agent.agent_beliefs.get(id,{})
		if agent.position.distance_to(agent.threats[id].position) < agent.position.distance_to(agent.threats[nearest].position): nearest = id
		enemy_strength += float(belief.get("condition",.67))
	var threat: Vector2 = agent.threats[nearest].position
	var own_strength = agent.body.health*(1-.4*agent.body.fatigue)*(1-.3*agent.body.deprivation)
	var caution = agent.personality.caution
	var best: Dictionary = {}
	var best_gain := 0.0
	var direction = (agent.position-threat).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	# Eight bounded candidates include shorter nearby exits in confined spaces.
	for i in range(8):
		var length = 3.0 if i < 4 else .9
		var angle = [0.0,PI*.5,-PI*.5,PI,PI*.25,-PI*.25,PI*.75,-PI*.75][i]
		var point = agent.position+direction.rotated(angle)*length
		var gain := INF
		for id in active:
			var location: Vector2 = agent.threats[id].position
			gain = minf(gain,point.distance_to(location)-agent.position.distance_to(location))
		if gain <= maxf(.05,best_gain): continue
		var route = simulation.navigation.route(agent.position,point,agent.radius)
		if route.status != &"OK": continue
		var safe := true
		for id in active:
			var location: Vector2 = agent.threats[id].position
			var before = agent.position
			var clearance = maxf(0,before.distance_to(location)-.05)
			for waypoint in route.points:
				if Geometry2D.get_closest_point_to_segment(location,before,waypoint).distance_to(location) < clearance: safe = false; break
				before = waypoint
			if not safe: break
		if not safe: continue
		best_gain = gain
		best = {"kind":&"flee","key":"flee:%d" % nearest,"target":nearest,"position":point,"route_points":route.points,"route_revision":simulation.model.structures.traversal_revision,"score":1000+15*minf(1,gain/3)+20*caution+10*(enemy_strength-own_strength),"urgent":true,"reason":"Escaping: distance is safer than a fight."}
	var options: Array = []
	if not best.is_empty(): options.append(best)
	var defense_target: int = nearest
	var nearest_visible := INF
	for id in active:
		var sighting: Dictionary = agent.agent_beliefs.get(id,{})
		if sighting.is_empty() or sighting.observed_at != simulation.time: continue
		var distance = agent.position.distance_to(sighting.position)
		if distance < nearest_visible: defense_target = id; nearest_visible = distance
	var observed: Dictionary = agent.agent_beliefs.get(defense_target,{})
	if not observed.is_empty() and observed.observed_at == simulation.time:
		var contact = agent.radius+float(observed.radius)+simulation._profile.contact_margin
		if agent.position.distance_to(observed.position) <= contact or best.is_empty():
			options.append({"kind":&"defend","key":"defend:%d" % defense_target,"target":defense_target,"position":observed.position,"score":1100.0 if best.is_empty() else 1000+60*(own_strength-enemy_strength)-10*caution+20*agent.desperation,"urgent":true,"reason":"No safe escape; defending myself." if best.is_empty() else "Defending: I appear better able to withstand this fight."})
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
	var contact = agent.radius+float(belief.radius)+simulation._profile.contact_margin
	if control.current.kind == &"defend" and (not visible_now or agent.position.distance_to(location) > contact):
		agent.action = &"guarding"
		control.route_points.clear()
		return
	if agent.position.distance_to(location) <= agent.radius+float(belief.radius)+simulation._profile.contact_margin:
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
