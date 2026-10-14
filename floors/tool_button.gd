@tool
extends Button
## Generic presentation: no knowledge of construction geometry or tool IDs.
var definition: ConstructionToolDefinition
var paper_color := Color("eee8d9")
var selected_color := Color("c2cdc1")
var ink_color := Color("39433e")
var border_width := 2
var corner_radius := 9
var icon_width := 3.5

func _ready() -> void:
	flat = false
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_force_pass_scroll_events = false
	if definition.icon == null:
		text = definition.display_name
	tooltip_text = definition.tooltip

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if definition != null and definition.icon != null:
		var extent := minf(size.x, size.y) * 0.69
		# Retain the old icon_width export as an icon scale control for textures.
		extent *= clampf(icon_width / 3.5, 0.5, 1.25)
		draw_texture_rect(definition.icon, Rect2((size - Vector2.ONE * extent) / 2, Vector2.ONE * extent), false, ink_color * Color(1, 1, 1, 0.4 if disabled else 1.0))
