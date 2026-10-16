class_name PolygonBody
extends RefCounted
## Normalized physical state. Only the body applies interaction effects.
var deprivation := 0.0
var nourishment := 0.65
var fatigue := 0.15
var health := 1.0
var hunger_rate := 0.004
var fatigue_rate := 0.003
var starvation_threshold := 0.1
var starvation_damage := 0.02
func alive() -> bool:
	return health > 0.0
func hunger() -> float:
	return 1.0 - nourishment
func tick(delta: float) -> void:
	if not alive() or delta <= 0 or not is_finite(delta): return
	var harm = EmergencyAssessment.damage_over(self,delta)
	nourishment = clampf(nourishment - hunger_rate * delta, 0, 1)
	fatigue = clampf(fatigue + fatigue_rate * delta, 0, 1)
	damage(harm)
func apply_effects(effects: Dictionary) -> void:
	if not alive(): return
	nourishment = clampf(nourishment + float(effects.get(&"nourishment", 0)), 0, 1)
	fatigue = clampf(fatigue + float(effects.get(&"fatigue", 0)), 0, 1)
func damage(amount: float) -> void:
	if is_finite(amount) and amount > 0: health = maxf(0, health - amount)

func tick_deprivation(delta: float,profile: EmergencyProfile) -> void:
	if not alive() or delta <= 0 or not is_finite(delta): return
	var buildup = EmergencyAssessment.deficit_integral(nourishment,hunger_rate,profile.deprivation_threshold,delta)/profile.buildup_seconds
	var recovery_time = 0.0
	if nourishment >= profile.recovery_threshold:
		recovery_time = minf(delta,(nourishment-profile.recovery_threshold)/hunger_rate) if hunger_rate > 0 else delta
	deprivation = clampf(clampf(deprivation-recovery_time/profile.recovery_seconds,0,1)+buildup,0,1)
