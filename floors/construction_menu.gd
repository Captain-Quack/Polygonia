@tool
extends VBoxContainer
## A bottom-anchored category with its tools expanding upward. Child controls are
## generated, so only this one node needs adding to an existing scene.
const ToolButtonScript = preload("res://floors/tool_button.gd")

@export var category_title := "Construction Shapes"
@export var expanded := true:
	set(value):
		expanded = value
		if is_instance_valid(tools):
			var bottom_offset := offset_bottom
			tools.visible = value
			_update_category()
			_resize_to_tools.call_deferred(bottom_offset)
@export_group("Appearance")
@export var paper_color := Color("eee8d9")
@export var selected_color := Color("c2cdc1")
@export var ink_color := Color("39433e")
@export_range(40, 96, 1) var button_size := 58
@export_range(0, 24, 1) var button_gap := 10
@export_range(1, 8, 1) var border_width := 2
@export_range(0, 24, 1) var corner_radius := 9
@export_range(0.5, 8.0, 0.1) var icon_width := 3.5

var tools: HBoxContainer
var category: Button
var line_button: Button
var square_button: Button
var _appearance: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	tools = HBoxContainer.new()
	tools.name = "ShapeTools"
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tools)
	line_button = _make_tool("Line", 0, "Line — drag a grid edge; right-drag erases matching strokes")
	square_button = _make_tool("Square", 1, "Square — drag a filled area; right-drag erases floor")
	category = Button.new()
	category.name = "Category"
	category.toggle_mode = true
	category.focus_mode = Control.FOCUS_NONE
	category.mouse_force_pass_scroll_events = false
	category.custom_minimum_size = Vector2(220, 38)
	category.toggled.connect(func(value: bool): expanded = value)
	add_child(category)
	tools.visible = expanded
	_update_style()
	_update_category()

func _resize_to_tools(bottom_offset: float) -> void:
	# set_size() keeps the top position when shrinking. Restore the bottom
	# explicitly, so expanding upward cannot accumulate an offset each cycle.
	update_minimum_size()
	var height := get_combined_minimum_size().y
	size = Vector2(size.x, height)
	offset_bottom = bottom_offset
	offset_top = bottom_offset - height

func _make_tool(label: String, kind: int, hint: String) -> Button:
	var button := Button.new()
	button.set_script(ToolButtonScript)
	button.name = label
	button.tool_kind = kind
	button.tooltip_text = hint
	tools.add_child(button)
	return button

func _process(_delta: float) -> void:
	if not is_instance_valid(category):
		return
	var appearance := [paper_color, selected_color, ink_color, button_size, button_gap, icon_width, category_title, border_width, corner_radius]
	if appearance != _appearance:
		_update_style()
		_update_category()
		_appearance = appearance

func _update_category() -> void:
	if not is_instance_valid(category):
		return
	category.text = ("▾  " if expanded else "▸  ") + category_title
	category.set_pressed_no_signal(expanded)
	category.tooltip_text = "Collapse shape tools" if expanded else "Expand shape tools"

func _update_style() -> void:
	add_theme_constant_override("separation", 8)
	tools.add_theme_constant_override("separation", button_gap)
	for button in [line_button, square_button]:
		button.paper_color = paper_color
		button.selected_color = selected_color
		button.ink_color = ink_color
		button.icon_width = icon_width
		button.border_width = border_width
		button.corner_radius = corner_radius
		button.custom_minimum_size = Vector2.ONE * button_size
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = selected_color if "pressed" in state else paper_color
		style.border_color = ink_color
		style.set_border_width_all(border_width)
		style.set_corner_radius_all(corner_radius)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.anti_aliasing = true
		category.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		category.add_theme_color_override(state, ink_color)
