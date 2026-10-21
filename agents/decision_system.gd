class_name AgentDecision
extends RefCounted
static func candidates(agent: PolygonAgent,now: float,revision: int,simulation: AgentSimulation = null) -> Array:
	var result: Array = [{"kind":&"idle","key":"idle","score":0.03}]
	for key in agent.beliefs:
		var b: Dictionary = agent.beliefs[key]
		if not b.available: continue
		var admitted = agent.controller.current.get("key","") == key and agent.controller.provider != null and agent.controller.provider.active and agent.controller.provider.has_user(agent.id)
		if not admitted and b.get("requirement",&"") == &"extreme_feeding" and (simulation == null or not AgentThreatActions.eligible(agent,simulation._profile)): continue
		if now < b.retry_at and b.failed_revision == revision: continue
		if not admitted and b.interaction == &"eat" and agent.body.hunger() < 0.25: continue
		if b.interaction == &"rest" and agent.body.fatigue < AgentNeeds.REST_TARGET: continue
		var option = b.duplicate(true)
		option.kind = &"interact"
		option.score = AgentNeeds.score(agent.body,b.effects) / (1.0 + agent.position.distance_to(b.position) * 0.12)
		if b.interaction == &"rest":
			option.score = AgentNeeds.rest_score(agent.body,maxf(0,-float(b.effects.get(&"fatigue",0))),b.duration,agent.position.distance_to(b.position),agent.speed)
		result.append(option)
	if agent.body.fatigue >= AgentNeeds.REST_TARGET:
		result.append({"kind":&"ground_rest","key":"ground_rest","score":AgentNeeds.rest_score(agent.body,AgentNeeds.GROUND_REST_RECOVERY,1.0,0,agent.speed)})
	if agent.body.hunger() > 0.3:
		result.append({"kind":&"explore","key":"explore","score":pow(agent.body.hunger(),2)*0.3})
	result.sort_custom(func(a,b): return a.score > b.score)
	if simulation != null:
		result = AgentOptionEvaluator.evaluate(agent,result,simulation)
		var food_contests = AgentFoodSocial.candidates(agent,simulation)
		# A food contest supersedes predation; avoid assessing both sets of routes.
		result.append_array(food_contests if not food_contests.is_empty() else AgentThreatActions.candidates(agent,simulation))
		result.sort_custom(func(a,b): return a.score > b.score)
	return result

