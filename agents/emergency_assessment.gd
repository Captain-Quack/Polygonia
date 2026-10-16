class_name EmergencyAssessment
extends RefCounted
## Exact integral of linearly declining nourishment below a threshold.
static func deficit_integral(n: float,drain: float,threshold: float,seconds: float) -> float:
	if seconds <= 0 or threshold <= 0: return 0.0
	n = maxf(0,n); drain = maxf(0,drain)
	if drain == 0: return clampf(1-n/threshold,0,1)*seconds
	var start = maxf(0,(n-threshold)/drain)
	var empty = n/drain
	var end = minf(seconds,empty)
	var ramp = 0.0
	if end > start:
		ramp = ((1-(n-drain*start)/threshold)+(1-(n-drain*end)/threshold))*(end-start)*.5
	return ramp+maxf(0,seconds-empty)
static func damage_over(body: PolygonBody,seconds: float) -> float:
	return maxf(0,body.starvation_damage)*deficit_integral(body.nourishment,body.hunger_rate,body.starvation_threshold,seconds)
static func fatal_after(body: PolygonBody) -> float:
	if not body.alive(): return 0.0
	if body.starvation_damage <= 0 or body.starvation_threshold <= 0: return INF
	if body.hunger_rate <= 0:
		var rate = damage_over(body,1)
		return body.health/rate if rate > 0 else INF
	var low := 0.0
	var high = maxf(0,body.nourishment)/body.hunger_rate+body.health/body.starvation_damage
	for i in range(50):
		var middle = (low+high)*.5
		if damage_over(body,middle) >= body.health: high = middle
		else: low = middle
	return high
static func evaluate(body: PolygonBody,profile: EmergencyProfile) -> Dictionary:
	var deadline = fatal_after(body)
	var harm = damage_over(body,.1)/.1
	var urgency = clampf(1.0-deadline/30.0,0,1) if is_finite(deadline) else 0.0
	return {"urgency":urgency,"impairment":body.deprivation,"mobility":1-profile.mobility_penalty*body.deprivation,"fatal_after":deadline,"harm_rate":harm}
