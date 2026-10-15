class_name PolygonBody
extends RefCounted
## Normalized physical state. Only the body applies interaction effects.
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
	nourishment = clampf(nourishment - hunger_rate * delta, 0, 1)
	fatigue = clampf(fatigue + fatigue_rate * delta, 0, 1)
	if nourishment < starvation_threshold:
		damage(starvation_damage * (1.0 - nourishment / starvation_threshold) * delta)
func apply_effects(effects: Dictionary) -> void:
	if not alive(): return
	nourishment = clampf(nourishment + float(effects.get(&"nourishment", 0)), 0, 1)
	fatigue = clampf(fatigue + float(effects.get(&"fatigue", 0)), 0, 1)
func damage(amount: float) -> void:
	if is_finite(amount) and amount > 0: health = maxf(0, health - amount)
