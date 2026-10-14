@tool
class_name ConstructionCategoryDefinition
extends Resource
@export var category_id: StringName = &"":
	set(value):
		category_id = value
		emit_changed()
@export var title := "New category":
	set(value):
		title = value
		emit_changed()
@export var default_expanded := true:
	set(value):
		default_expanded = value
		emit_changed()
@export var tools: Array[ConstructionToolDefinition] = []:
	set(value):
		tools = value
		emit_changed()
