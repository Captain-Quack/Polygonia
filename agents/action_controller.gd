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
func reconsider(agent: PolygonAgent,options: Array,now: float,urgent: bool = false) -> void:
	var best: Dictionary = options[0]
	if not current.is_empty():
		var existing: Dictionary = {}
		for option in options:
			if option.key == current.key: existing = option; break
		if not existing.is_empty() and (best.key == existing.key or (not urgent and best.score < existing.score + 0.12)):
			# A newly observed position can legitimately redirect an existing intention.
			if existing.get("position") == current.get("position"):
				current.merge(existing,true); agent.decision_reason = existing.get("reason",agent.decision_reason); return
			best = existing
	# Defending a meal retains its admission; fleeing and other interruptions release it.
	var guarded: InteractionProvider
	var guarded_progress = progress
	var meal_key = current.get("meal_key",current.get("key",""))
	var keep_meal = best.kind == &"defend" or (best.kind == &"interact" and best.key == meal_key)
	if keep_meal and provider is FoodInteractionProvider and provider.active and provider.has_user(agent.id):
		guarded = provider; provider = null
	cancel(agent)
	if guarded != null: provider = guarded; progress = guarded_progress
	current = best.duplicate(true)
	if guarded != null and best.kind == &"defend": current.meal_key = meal_key
	agent.decision_reason = best.get("reason","Balancing needs.")
	if best.has("route_points"):
		route_points = best.route_points.duplicate(); route_revision = best.route_revision
	wait_until = now
	agent.action = best.kind
func _fail(agent: PolygonAgent,now: float,revision: int,reason: String) -> void:
	if agent.beliefs.has(current.get("key","")):
		var belief: Dictionary = agent.beliefs[current.key]
		belief.retry_at = now + (0.5 if reason == "Resource busy or depleted." else 8.0); belief.failed_revision = revision
	agent.report_setback(now)
	agent.remember_event(reason)
	cancel(agent)
	agent.next_decision = now + 0.5
func tick(agent: PolygonAgent,simulation,delta: float) -> void:
	if current.is_empty(): return
	var now: float = simulation.time
	var nav: AgentNavigation = simulation.navigation
	var revision: int = simulation.model.structures.traversal_revision
	if current.kind == &"contest_food":
		AgentFoodSocial.tick_contest(agent,simulation,delta); return
	if current.kind in [&"pursue",&"flee",&"defend"]:
		AgentThreatActions.tick(agent,simulation,delta); return
	match current.kind:
		&"ground_rest":
			agent.action = &"resting on ground"
			agent.body.apply_effects({&"fatigue":-AgentNeeds.GROUND_REST_RECOVERY*delta})
		&"idle": agent.action = &"idle"
		&"explore":
			var panic = EmergencyAssessment.is_panicking(agent)
			if panic:
				agent.action = &"panicking"
				agent.decision_reason = "Panicking: searching for a way out."
				agent.next_decision = minf(agent.next_decision,now+.1)
				wait_until = minf(wait_until,now+.75)
			# New geometry can provide an exit while the old retry is waiting.
			if route_revision != revision and route_points.is_empty(): wait_until = now
			if now < wait_until:
				if not panic: agent.action = &"waiting: no route"
				return
			if route_points.is_empty():
				var search = agent.exploration.choose(agent,nav)
				route_revision = revision
				if search.is_empty():
					agent.report_setback(now)
					wait_until = now + (.75 if panic else 3.0)
					agent.action = &"panicking" if panic else &"waiting: no route"
					return
				if search.get("constrained",false): agent.report_setback(now)
				route_points = search.points
			agent.action = &"panicking" if panic else &"searching"
			if not _move(agent,nav,delta):
				agent.report_setback(now); route_points.clear(); wait_until = now + (.75 if panic else 1.0)
			elif route_points.is_empty(): agent.exploration.reached(agent.position)

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
				if current.get("requirement",&"") == &"extreme_feeding" and not AgentThreatActions.eligible(agent,simulation._profile):
					cancel(agent); return
				provider = object.providers[current.provider]
				if not provider.begin(agent.id):
					_fail(agent,now,revision,"Resource busy or depleted."); return
			agent.action = (&"sharing food" if now < agent.food_gesture_until else &"eating") if current.interaction == &"eat" else &"resting"
			var previous_progress = progress
			progress += delta
			if current.get("requirement",&"") == &"extreme_feeding" and provider.active and provider.has_user(agent.id) and int(progress/.5) > int(previous_progress/.5):
				simulation.gore.bite(agent.id,object.position,agent.position)
			if progress >= maxf(0.1,provider.definition.duration):
				var effects = provider.complete(agent.id)
				if not effects.is_empty():
					agent.body.apply_effects(effects)
					agent.familiarity[current.key] = int(agent.familiarity.get(current.key,0))+1
					agent.remember_event("Ate a portion." if current.interaction == &"eat" else "Rested.")
					# Keep the place reserved between recovery pulses until the session ends.
					if current.interaction == &"rest" and agent.body.fatigue > AgentNeeds.REST_TARGET and provider.begin(agent.id):
						progress = 0.0
						return
				cancel(agent); agent.next_decision = now; agent.next_perception = now
func _move(agent: PolygonAgent,nav: AgentNavigation,delta: float) -> bool:
	var remaining = agent.effective_speed() * delta
	while remaining > 0 and not route_points.is_empty():
		var target: Vector2 = route_points[0]
		var distance = agent.position.distance_to(target)
		if distance < 0.001: route_points.pop_front(); continue
		var next = agent.position.move_toward(target,remaining)
		if not nav.prepare_step(agent.position,next,agent.radius,agent.id): return false
		agent.facing = (next-agent.position).angle()
		agent.position = next; remaining -= distance
		agent.motion.record(next,agent.facing)
		if agent.position.distance_to(target) < 0.001: route_points.pop_front()
	return true

