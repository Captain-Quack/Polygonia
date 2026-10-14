@tool
extends Button
const Geometry = preload("res://floors/shape_geometry.gd")

@export_enum("Line", "Square") var tool_kind := 0
@export var paper_color := Color("eee8d9")
@export var selected_color := Color("c2cdc1")
@export var ink_color := Color("39433e")
@export_range(1, 8, 1) var border_width := 2
@export_range(0, 24, 1) var corner_radius := 9
@export_range(0.5, 8.0, 0.1) var icon_width := 3.5

func _ready() -> void:
	flat = true
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_force_pass_scroll_events = false
	custom_minimum_size = Vector2(58, 58)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = selected_color if button_pressed else paper_color
	if is_hovered():
		style.bg_color = style.bg_color.lightened(0.05)
	style.border_color = ink_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.anti_aliasing = true
	draw_style_box(style, Rect2(Vector2(2, 2), size - Vector2(4, 4)))
	var center := size * 0.5
	if tool_kind == 0:
		Geometry.round_stroke(self, PackedVector2Array([center + Vector2(-11, 9), center + Vector2(11, -9)]), ink_color, icon_width)
	else:
		var points := PackedVector2Array([center + Vector2(-11, -11), center + Vector2(11, -11), center + Vector2(11, 11), center + Vector2(-11, 11)])
		var rounded := Geometry.rounded_loop(points, 4.0)
		draw_colored_polygon(rounded, Color(ink_color, 0.2))
		Geometry.round_stroke(self, rounded, ink_color, icon_width, true)
