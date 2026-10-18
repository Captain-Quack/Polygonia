class_name EmergencyProfile
extends Resource
## Game parameters, not clinical measurements. Simulations retain a validated copy.
@export var deprivation_threshold := 0.25
@export var recovery_threshold := 0.40
@export var buildup_seconds := 120.0
@export var recovery_seconds := 180.0
@export var mobility_penalty := 0.25
@export var constraint_buildup_seconds := 20.0
@export var constraint_recovery_seconds := 15.0
@export var setback_memory_seconds := 6.0
@export var desperate_feeding_threshold := 0.65
@export var predation_enabled := true
## Reachable during a first starvation episode under the default body rates.
@export var predation_deprivation := 0.35
@export var predation_nourishment := 0.10
@export var strike_interval := 1.0
@export var strike_damage := 0.10
@export var contact_margin := 0.10
@export var edible_yield := 0.45
@export var consumption_duration := 2.0
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for key in ["constraint_buildup_seconds","constraint_recovery_seconds","setback_memory_seconds","desperate_feeding_threshold","deprivation_threshold","recovery_threshold","buildup_seconds","recovery_seconds","mobility_penalty","predation_deprivation","predation_nourishment","strike_interval","strike_damage","contact_margin","edible_yield","consumption_duration"]:
		var value = float(get(key))
		if not is_finite(value) or value < 0: errors.append("Invalid " + key)
	for key in ["constraint_buildup_seconds","constraint_recovery_seconds","setback_memory_seconds","buildup_seconds","recovery_seconds","strike_interval","consumption_duration","deprivation_threshold"]:
		if float(get(key)) <= 0: errors.append("Must be positive: " + key)
	for key in ["desperate_feeding_threshold","deprivation_threshold","recovery_threshold","mobility_penalty","predation_deprivation","predation_nourishment","edible_yield"]:
		if float(get(key)) > 1: errors.append("Must be normalized: " + key)
	if recovery_threshold <= deprivation_threshold: errors.append("Recovery must exceed deprivation threshold")
	return errors
