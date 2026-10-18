class_name AgentOptionEvaluator
extends RefCounted
static func evaluate(agent: PolygonAgent,options: Array,simulation: AgentSimulation) -> Array:
	var weights = AgentMotivation.weights(agent)
	var validated := 0
	var budget = agent.consideration_limit()
	var food_found := false
	var timely_food := false
	var ordinary_food_unchecked := false
	var interactions: Array = []
	for option in options:
		option.reason = "Balancing hunger and fatigue."
		if option.kind == &"interact":
			option.score *= 1.0 + minf(1,float(agent.familiarity.get(option.key,0))/5.0)*agent.body.deprivation*agent.personality.persistence*.25
			interactions.append(option)
	# Always assess the current intention. Rotate only its alternatives so an
	# impaired agent cannot abandon a meal just because its slot was not visited.
	interactions.sort_custom(func(a,b): return a.score > b.score)
	var retained: Array = []
	for option in interactions:
		if option.key == agent.controller.current.get("key",""):
			retained.append(option); break
	for option in retained: interactions.erase(option)
	var alternative_budget = budget-retained.size()
	if interactions.size() > alternative_budget:
		var offset = agent.route_cursor % interactions.size()
		interactions = interactions.slice(offset)+interactions.slice(0,offset)
		agent.route_cursor += alternative_budget
	interactions = retained+interactions
	for option in interactions:
		option.route_status = &"UNCERTAIN"
		if validated >= budget:
			if option.interaction == &"eat" and option.get("requirement",&"") == &"": ordinary_food_unchecked = true
			option.score = 0.0
			option.reason = "Opportunity awaits route assessment."
			continue
		validated += 1
		var route = simulation.navigation.route(agent.position,option.position,agent.radius)
		option.route_status = route.status
		if route.status != &"OK":
			agent.report_setback(simulation.time)
			option.score = -1
			var belief: Dictionary = agent.beliefs.get(option.key,{})
			belief.retry_at = simulation.time+8
			belief.failed_revision = simulation.model.structures.traversal_revision
			agent.remember_event("Route unavailable (%s); trying something else." % route.status)
			continue
		option.route_points = route.points
		option.route_revision = simulation.model.structures.traversal_revision
		var distance := 0.0
		var previous = agent.position
		for point in route.points:
			distance += previous.distance_to(point); previous = point
		var remaining = float(option.duration)
		if agent.controller.current.get("key","") == option.key: remaining = maxf(0,remaining-agent.controller.progress)
		option.relief_after = maxf(0,distance-.25)/maxf(.01,agent.effective_speed())+remaining+.1
		option.predicted_health = agent.body.health-EmergencyAssessment.damage_over(agent.body,option.relief_after)
		if option.interaction == &"eat":
			food_found = true
			var timely = option.predicted_health > 0
			if timely and option.get("requirement",&"") == &"": timely_food = true
			option.score *= weights.food
			if weights.danger:
				option.score += (100.0 if timely else 10.0)+10.0/(1.0+option.relief_after)
				option.reason = "Food cannot wait: ongoing starvation threatens health." if timely else "Attempting the best remaining chance of nourishment."
			option.urgent = weights.danger
	for option in options:
		if option.kind == &"explore" and weights.danger and not food_found:
			option.score = 20.0
			option.urgent = true
			option.reason = "Repeated setbacks; urgently searching for another way to food." if agent.constraint_pressure > .5 else "No known food; searching urgently."
	options = options.filter(func(o): return o.score >= 0)
	options.sort_custom(func(a,b): return a.score > b.score)
	agent.timely_food = timely_food
	agent.ordinary_food_unchecked = ordinary_food_unchecked
	return options
