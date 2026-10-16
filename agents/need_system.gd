class_name AgentNeeds
extends RefCounted
const REST_TARGET := 0.2
const GROUND_REST_RECOVERY := 0.028
const REST_WEIGHT := 1.2
static func score(body: PolygonBody,effects: Dictionary) -> float:
	var hunger = body.hunger()
	var food_relief = minf(hunger,maxf(0,float(effects.get(&"nourishment",0))))
	var rest_relief = minf(body.fatigue,maxf(0,-float(effects.get(&"fatigue",0))))
	return food_relief * hunger * hunger * 8.0 + rest_relief * pow(body.fatigue,3) * 25.0

## Compare entire rest sessions rather than one short recovery pulse against ground rest.
## Travel cost is paid once; recovery speed includes fatigue accumulating during rest.
static func rest_score(body: PolygonBody,recovery: float,duration: float,distance: float,speed: float) -> float:
	var net_rate = recovery / maxf(duration,0.1) - body.fatigue_rate
	var deficit = maxf(0,body.fatigue - REST_TARGET)
	if net_rate <= 0 or deficit <= 0: return 0.0
	var ground_rate = maxf(0.001,GROUND_REST_RECOVERY - body.fatigue_rate)
	var rest_time = deficit / net_rate
	var travel_time = distance / maxf(0.01,speed * (1.0 - body.fatigue * 0.35))
	return REST_WEIGHT * pow(body.fatigue,3) * (net_rate / ground_rate) * rest_time / (rest_time + travel_time)
