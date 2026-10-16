class_name WorldObjectDefinition
extends Resource
@export var definition_id: StringName
@export var display_name := "Object"
@export var color := Color(0.35, 0.55, 0.35)
@export var interactions: Array[InteractionDefinition] = []

## Consumable piles can disappear after every offered capability is exhausted.
@export var remove_when_depleted := false
