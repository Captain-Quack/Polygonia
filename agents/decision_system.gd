class_name AgentDecision
extends RefCounted
static func candidates(agent: PolygonAgent,now: float,revision: int) -> Array:
	var result: Array = [{"kind":&"idle","key":"idle","score":0.03}]
	for key in agent.beliefs:
		var b: Dictionary = agent.beliefs[key]
		if not b.available: continue
		if now < b.retry_at and b.failed_revision == revision: continue
		if b.interaction == &"eat" and agent.body.hunger() < 0.25: continue
		if b.interaction == &"rest" and agent.body.fatigue < 0.2: continue
		var option = b.duplicate(true)
		option.kind = &"interact"
		option.score = AgentNeeds.score(agent.body,b.effects) / (1.0 + agent.position.distance_to(b.position) * 0.12)
		result.append(option)
	if agent.body.fatigue >= 0.2:
		result.append({"kind":&"ground_rest","key":"ground_rest","score":pow(agent.body.fatigue,3)*1.2})
	if agent.body.hunger() > 0.3:
		result.append({"kind":&"explore","key":"explore","score":pow(agent.body.hunger(),2)*0.3})
	result.sort_custom(func(a,b): return a.score > b.score)
	return result
