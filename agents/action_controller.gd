class_name AgentActionController
extends RefCounted
## Executes intentions; navigation and world interactions own their respective effects.
var current: Dictionary = {}
var route_points: Array = []
var provider: InteractionProvider
var progress := 0.0
var route_revision := -1
var wait_until := 0.0
func cancel(agent: PolygonAgent) -> void:
	if provider != null: provider.cancel(agent.id)
	provider = null; progress = 0; route_points.clear(); current.clear()
	agent.action = &"idle"
func reconsider(agent: PolygonAgent,options: Array,now: float) -> void:
	var best: Dictionary = options[0]
	if not current.is_empty():
		var existing: Dictionary = {}
		for option in options:
			if option.key == current.key: existing = option; break
		if not existing.is_empty() and best.score < existing.score + 0.12:
			# A newly observed position can legitimately redirect an existing intention.
			if existing.get("position") == current.get("position"):
				current.score = existing.score; return
			best = existing
	cancel(agent)
	current = best.duplicate(true)
	wait_until = now
	agent.action = best.kind
func _fail(agent: PolygonAgent,now: float,revision: int,reason: String) -> void:
	if agent.beliefs.has(current.get("key","")):
		var belief: Dictionary = agent.beliefs[current.key]
		belief.retry_at = now + 8.0; belief.failed_revision = revision
	agent.remember_event(reason)
	cancel(agent)
	agent.next_decision = now + 0.5
func tick(agent: PolygonAgent,simulation,delta: float) -> void:
	if current.is_empty(): return
	var now: float = simulation.time
	var nav: AgentNavigation = simulation.navigation
	var revision: int = simulation.model.structures.traversal_revision
	match current.kind:
		&"ground_rest":
			agent.action = &"resting on ground"
			agent.body.apply_effects({&"fatigue":-0.028*delta})
		&"idle": agent.action = &"idle"
		&"explore":
			if now < wait_until: return
			if route_points.is_empty():
				var found := false
				for attempt in range(4):
					agent.exploration_index += 1
					var angle = agent.exploration_index * 2.399963 + agent.id
					var goal = agent.position + Vector2.from_angle(angle) * 4.0
					var route = nav.route(agent.position,goal,agent.radius)
					if route.status == &"OK":
						route_points = route.points; route_revision = revision; found = true; break
				if not found:
					wait_until = now + 3.0; agent.action = &"waiting: no route"; return
			agent.action = &"searching"
			if not _move(agent,nav,delta): route_points.clear(); wait_until = now + 1.0
		&"interact":
			# Perception may disprove a remembered target; do not follow world truth remotely.
			if not agent.beliefs.has(current.key):
				_fail(agent,now,revision,"Resource missing; searching again."); return
			var destination: Vector2 = current.position
			if agent.position.distance_to(destination) > 0.25:
				agent.action = &"seeking food" if current.interaction == &"eat" else &"seeking rest"
				if route_points.is_empty() or route_revision != revision:
					var route = nav.route(agent.position,destination,agent.radius)
					if route.status != &"OK":
						_fail(agent,now,revision,"Route unavailable (%s); trying something else." % route.status); return
					route_points = route.points; route_revision = revision
				if not _move(agent,nav,delta):
					_fail(agent,now,revision,"Movement blocked; reconsidering route.")
				return
			var object = simulation.objects.get_object(current.source)
			if object == null or object.position.distance_to(destination) > 0.01 or object.revision != current.revision or not AgentPerception.visible(agent,object.position,simulation.model):
				_fail(agent,now,revision,"Resource changed before use."); return
			if provider == null:
				provider = object.providers[current.provider]
				if not provider.begin(agent.id):
					_fail(agent,now,revision,"Resource busy or depleted."); return
			agent.action = &"eating" if current.interaction == &"eat" else &"resting"
			progress += delta
			if progress >= maxf(0.1,provider.definition.duration):
				var effects = provider.complete(agent.id)
				if not effects.is_empty():
					agent.body.apply_effects(effects)
					agent.remember_event("Ate a portion." if current.interaction == &"eat" else "Rested.")
				cancel(agent); agent.next_decision = now; agent.next_perception = now
func _move(agent: PolygonAgent,nav: AgentNavigation,delta: float) -> bool:
	var remaining = agent.speed * (1.0 - agent.body.fatigue * 0.35) * delta
	while remaining > 0 and not route_points.is_empty():
		var target: Vector2 = route_points[0]
		var distance = agent.position.distance_to(target)
		if distance < 0.001: route_points.pop_front(); continue
		var next = agent.position.move_toward(target,remaining)
		if not nav.prepare_step(agent.position,next,agent.radius,agent.id): return false
		agent.facing = (next-agent.position).angle()
		agent.position = next; remaining -= distance
		if agent.position.distance_to(target) < 0.001: route_points.pop_front()
	return true
