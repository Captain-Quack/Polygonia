class_name AgentNeeds
extends RefCounted
static func score(body: PolygonBody,effects: Dictionary) -> float:
	var hunger = body.hunger()
	var food_relief = minf(hunger,maxf(0,float(effects.get(&"nourishment",0))))
	var rest_relief = minf(body.fatigue,maxf(0,-float(effects.get(&"fatigue",0))))
	return food_relief * hunger * hunger * 8.0 + rest_relief * pow(body.fatigue,3) * 25.0
