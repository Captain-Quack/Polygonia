class_name InteractionDefinition
extends Resource
## Shared immutable configuration; providers own runtime stock and users.
@export var interaction_id: StringName = &"eat"
@export var duration := 2.0
@export var nourishment := 0.45
@export var fatigue := 0.0
@export var capacity := 1
## -1 means unlimited; nonnegative stock is consumed once on completion.
@export var initial_stock := 8
func effects() -> Dictionary:
	return {&"nourishment": nourishment, &"fatigue": fatigue}

## Override in a specialized definition to supply a different provider implementation.
func create_provider() -> InteractionProvider:
	return InteractionProvider.new(self)
