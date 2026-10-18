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
	for turn in [0.0,PI*.5,-PI*.5,PI]:
		var angle = heading+turn+_rng.randf_range(-.2,.2)
		var goal = agent.position+Vector2.from_angle(angle)*LEG_LENGTH
		var route = nav.route(agent.position,goal,agent.radius)
		if route.status != &"OK": continue
		var clearance := INF
		for previous in _recent: clearance = minf(clearance,goal.distance_to(previous))
		var result = {"points":route.points,"heading":angle}
		if clearance >= LEG_LENGTH*.5:
			heading = angle
			return result
		if clearance > fallback_clearance:
			fallback = result; fallback_clearance = clearance
	# Backtracking is allowed when walls leave no new reachable destination.
	if not fallback.is_empty(): heading = fallback.heading
	return fallback
