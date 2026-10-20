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
	# Invert the same piecewise starvation integral used by damage_over.
	# Before the threshold there is no damage, then a quadratic ramp,
	# followed by constant damage once nourishment reaches zero.
	var n = maxf(0,body.nourishment)
	var threshold = body.starvation_threshold
	var drain = body.hunger_rate
	var wait = maxf(0,(n-threshold)/drain)
	var deficit = clampf(1-n/threshold,0,1)
	var ramp_seconds = minf(n,threshold)/drain
	var area = body.health/body.starvation_damage
	var ramp_area = (deficit+1)*ramp_seconds*.5
	if area >= ramp_area: return wait+ramp_seconds+(area-ramp_area)
	var slope = drain/threshold
	# Rationalized quadratic root avoids cancellation near full deficit.
	return wait+2*area/(sqrt(deficit*deficit+2*slope*area)+deficit)
static func evaluate(body: PolygonBody,profile: EmergencyProfile) -> Dictionary:
	var deadline = fatal_after(body)
	var harm = damage_over(body,.1)/.1
	var urgency = clampf(1.0-deadline/30.0,0,1) if is_finite(deadline) else 0.0
	return {"urgency":urgency,"impairment":body.deprivation,"mobility":1-profile.mobility_penalty*body.deprivation,"fatal_after":deadline,"harm_rate":harm}

static func update_context(agent: PolygonAgent,now: float,delta: float,profile: EmergencyProfile) -> void:
	var need = clampf((profile.recovery_threshold-agent.body.nourishment)/profile.recovery_threshold,0,1)
	if need > 0 and now-agent.last_setback_at <= profile.setback_memory_seconds:
		agent.constraint_pressure = minf(1,agent.constraint_pressure+delta/profile.constraint_buildup_seconds)
	else:
		agent.constraint_pressure = maxf(0,agent.constraint_pressure-delta/profile.constraint_recovery_seconds)
	agent.desperation = clampf(need*(.2+.3*agent.body.deprivation+.5*agent.constraint_pressure)+.3*float(agent.assessment.get("urgency",0)),0,1)
	agent.assessment.desperation = agent.desperation
	agent.assessment.constraints = agent.constraint_pressure

## A derived response, not another persistent need or independent state machine.
static func is_panicking(agent: PolygonAgent) -> bool:
	return agent.body.alive() and agent.constraint_pressure >= .5 and agent.desperation >= .65
