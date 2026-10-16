class_name EmergencyProfile
extends Resource
## Game parameters, not clinical measurements. Simulations retain a validated copy.
@export var deprivation_threshold := 0.25
@export var recovery_threshold := 0.40
@export var buildup_seconds := 120.0
@export var recovery_seconds := 180.0
@export var mobility_penalty := 0.25
@export var predation_enabled := true
@export var predation_deprivation := 0.65
@export var predation_nourishment := 0.10
@export var strike_interval := 1.0
@export var strike_damage := 0.10
@export var contact_margin := 0.10
@export var edible_yield := 0.45
@export var consumption_duration := 2.0
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for key in ["deprivation_threshold","recovery_threshold","buildup_seconds","recovery_seconds","mobility_penalty","predation_deprivation","predation_nourishment","strike_interval","strike_damage","contact_margin","edible_yield","consumption_duration"]:
		var value = float(get(key))
		if not is_finite(value) or value < 0: errors.append("Invalid " + key)
	for key in ["buildup_seconds","recovery_seconds","strike_interval","consumption_duration","deprivation_threshold"]:
		if float(get(key)) <= 0: errors.append("Must be positive: " + key)
	for key in ["deprivation_threshold","recovery_threshold","mobility_penalty","predation_deprivation","predation_nourishment","edible_yield"]:
		if float(get(key)) > 1: errors.append("Must be normalized: " + key)
	if recovery_threshold <= deprivation_threshold: errors.append("Recovery must exceed deprivation threshold")
	return errors
