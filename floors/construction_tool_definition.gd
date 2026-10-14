@tool
class_name ConstructionToolDefinition
extends Resource
## Menu presentation only. Match tool_id to a registered ConstructionToolHandler.
@export var tool_id: StringName = &"":
	set(value):
		tool_id = value
		emit_changed()
@export var display_name := "":
	set(value):
		display_name = value
		emit_changed()
@export_multiline var tooltip := "":
	set(value):
		tooltip = value
		emit_changed()
@export var icon: Texture2D:
	set(value):
		icon = value
		emit_changed()
