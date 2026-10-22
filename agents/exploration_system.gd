class_name AgentExploration
extends RefCounted
## Persistent, seeded search direction. Remembers only recently reached destinations.
const LEG_LENGTH := 4.0
const MEMORY_LIMIT := 8
var heading := 0.0
var _rng := RandomNumberGenerator.new()
var _recent: Array[Vector2] = []
func initialize(simulation_seed: int,agent_id: int,origin: Vector2) -> void:
	_rng.seed = simulation_seed+agent_id*65537
	heading = _rng.randf_range(-PI,PI)
	_recent = [origin]
func reached(point: Vector2) -> void:
	if not _recent.is_empty() and _recent[-1].distance_to(point) < .1: return
	_recent.append(point)
	if _recent.size() > MEMORY_LIMIT: _recent.pop_front()
func choose(agent: PolygonAgent,nav: AgentNavigation) -> Dictionary:
	var deferred := false
	for remembered in AgentCognition.recalled_destinations(agent):
		var route=nav.route(agent.position,remembered.point,agent.radius)
		if route.status==&"OK": return {"points":route.points,"heading":(remembered.point-agent.position).angle(),"constrained":false,"remembered":true}
		if route.status==&"DEFERRED": deferred=true
	var fallback: Dictionary = {}
	var fallback_clearance := -1.0
	# Twelve route probes at most. Short steps distinguish cramped movement
	# from having no reachable destination at all.
	for distance in [LEG_LENGTH,1.5,.5]:
		var turns=[0.0,PI*.5,-PI*.5,PI]
		# Preserve seeded baseline order when histories give no reason to differ.
		turns.sort_custom(func(a,b): return agent.memory.place(agent.position+Vector2.from_angle(heading+a)*distance,agent.memory.time).danger < agent.memory.place(agent.position+Vector2.from_angle(heading+b)*distance,agent.memory.time).danger)
		for turn in turns:
			var angle = heading+turn+_rng.randf_range(-.2,.2)
			var goal = agent.position+Vector2.from_angle(angle)*distance
			var route = nav.route(agent.position,goal,agent.radius)
			if route.status==&"DEFERRED": deferred=true
			if route.status != &"OK": continue
			var clearance := INF
			for previous in _recent: clearance = minf(clearance,goal.distance_to(previous))
			# A postponed longer probe says nothing about the available space.
			var result = {"points":route.points,"heading":angle,"constrained":distance < LEG_LENGTH and not deferred}
			if clearance >= distance*.5:
				heading = angle
				return result
			if clearance > fallback_clearance:
				fallback = result; fallback_clearance = clearance
		# Prefer an available full-length backtrack over declaring the space cramped.
		if not fallback.is_empty():
			heading = fallback.heading
			return fallback
	return {"deferred":true} if deferred else {}

