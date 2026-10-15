class_name PolygonWorldObject
extends RefCounted
var id := 0
var position := Vector2.ZERO
var definition: WorldObjectDefinition
var providers: Array[InteractionProvider] = []
var active := true
var revision := 0
func _init(config: WorldObjectDefinition = null) -> void:
	definition = config
	if config != null:
		for interaction in config.interactions:
			providers.append(interaction.create_provider())
func invalidate() -> void:
	active = false
	for provider in providers: provider.invalidate()
