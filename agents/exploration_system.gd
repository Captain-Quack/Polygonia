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
	var fallback: Dictionary = {}
	var fallback_clearance := -1.0
	# Twelve route probes at most. Short steps distinguish cramped movement
	# from having no reachable destination at all.
	for distance in [LEG_LENGTH,1.5,.5]:
		for turn in [0.0,PI*.5,-PI*.5,PI]:
			var angle = heading+turn+_rng.randf_range(-.2,.2)
			var goal = agent.position+Vector2.from_angle(angle)*distance
			var route = nav.route(agent.position,goal,agent.radius)
			if route.status != &"OK": continue
			var clearance := INF
			for previous in _recent: clearance = minf(clearance,goal.distance_to(previous))
			var result = {"points":route.points,"heading":angle,"constrained":distance < LEG_LENGTH}
			if clearance >= distance*.5:
				heading = angle
				return result
			if clearance > fallback_clearance:
				fallback = result; fallback_clearance = clearance
		# Prefer an available full-length backtrack over declaring the space cramped.
		if not fallback.is_empty():
			heading = fallback.heading
			return fallback
	return {}
