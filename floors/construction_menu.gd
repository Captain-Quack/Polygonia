@tool
extends VBoxContainer
## Resource-driven presentation. The editor supplies supported IDs at runtime.
signal tool_selected(tool_id: StringName)
const ToolButtonScript = preload("res://floors/tool_button.gd")
const DefaultCategory = preload("res://floors/tools/default_category.tres")
@export var categories: Array[ConstructionCategoryDefinition] = []
# Compatibility for scenes created before category resources were introduced.
@export var category_title := "Construction Shapes"
@export var expanded := true:
	set(value):
		expanded = value
		if categories.is_empty() and is_inside_tree():
			set_category_expanded(&"shapes", value)
@export_group("Appearance")
@export var paper_color := Color("eee8d9")
@export var selected_color := Color("c2cdc1")
@export var ink_color := Color("39433e")
@export_range(40, 96, 1) var button_size := 58
@export_range(0, 24, 1) var button_gap := 10
@export_range(1, 8, 1) var border_width := 2
@export_range(0, 24, 1) var corner_radius := 9
@export_range(0.5, 8.0, 0.1) var icon_width := 3.5
@export_range(1, 12, 1) var columns := 4
var selected_tool: StringName = &""
var buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var tool_grids: Dictionary = {}
var configuration_warnings := PackedStringArray()
var _supported: Array[StringName] = []
var _availability_known := false
var _expanded: Dictionary = {}
var _initial_expanded: Dictionary = {}
var _snapshot: Array = []
var _bottom := 0.0
var _observed: Array[Resource] = []
var _dirty := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom = offset_bottom
	rebuild()

func _configuration() -> Array:
	# Includes array contents: Inspector array edits need not emit Resource.changed.
	var result: Array = [category_title, expanded, paper_color, selected_color, ink_color, button_size, button_gap, border_width, corner_radius, icon_width, columns]
	var entries: Array = categories if not categories.is_empty() else [DefaultCategory]
	for entry in entries:
		result.append(entry)
		if entry == null:
			continue
		result.append_array([entry.category_id, entry.title, entry.default_expanded])
		for definition in entry.tools:
			result.append(definition)
			if definition != null:
				result.append_array([definition.tool_id, definition.display_name, definition.tooltip, definition.icon])
	return result

func _process(_delta: float) -> void:
	if _dirty or _configuration() != _snapshot:
		rebuild()

func rebuild() -> void:
	if not is_inside_tree():
		return
	_dirty = false
	_disconnect_resources()
	_snapshot = _configuration()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	category_buttons.clear()
	tool_grids.clear()
	configuration_warnings.clear()
	add_theme_constant_override("separation", 8)
	var entries: Array = categories
	if entries.is_empty():
		entries = [DefaultCategory]
	for entry in entries:
		_watch(entry)
		if entry == null or entry.category_id == &"" or category_buttons.has(entry.category_id):
			configuration_warnings.append("Skip null category or empty/duplicate category ID.")
			continue
		var id: StringName = entry.category_id
		var initial: bool = expanded if categories.is_empty() else entry.default_expanded
		if not _expanded.has(id) or _initial_expanded.get(id) != initial:
			_expanded[id] = initial
		_initial_expanded[id] = initial
		var grid := GridContainer.new()
		grid.columns = columns
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_theme_constant_override("h_separation", button_gap)
		grid.add_theme_constant_override("v_separation", button_gap)
		add_child(grid)
		tool_grids[id] = grid
		for definition in entry.tools:
			_watch(definition)
			if definition == null or definition.tool_id == &"" or buttons.has(definition.tool_id):
				configuration_warnings.append("Skip null tool or empty/duplicate tool ID in " + str(id) + ".")
				continue
			var button = ToolButtonScript.new()
			button.definition = definition
			button.paper_color = paper_color
			button.selected_color = selected_color
			button.ink_color = ink_color
			button.border_width = border_width
			button.corner_radius = corner_radius
			button.icon_width = icon_width
			button.custom_minimum_size = Vector2.ONE * button_size
			grid.add_child(button)
			_style(button)
			button.pressed.connect(select_tool.bind(definition.tool_id))
			buttons[definition.tool_id] = button
		var header := Button.new()
		header.text = category_title if categories.is_empty() else entry.title
		header.set_meta("title", header.text)
		header.toggle_mode = true
		header.focus_mode = Control.FOCUS_NONE
		header.mouse_force_pass_scroll_events = false
		header.custom_minimum_size = Vector2(220, 38)
		header.toggled.connect(func(value: bool): set_category_expanded(id, value))
		add_child(header)
		_style(header)
		category_buttons[id] = header
		set_category_expanded(id, _expanded[id])
	_refresh_availability()
	update_configuration_warnings()
	_fit.call_deferred()

func _get_configuration_warnings() -> PackedStringArray:
	return configuration_warnings

func _style(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = selected_color if "pressed" in state else paper_color
		style.border_color = ink_color
		style.set_border_width_all(border_width)
		style.set_corner_radius_all(corner_radius)
		style.content_margin_left = 12
		style.content_margin_right = 12
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink_color)

func set_category_expanded(id: StringName, value: bool) -> void:
	_expanded[id] = value
	if not category_buttons.has(id):
		return
	tool_grids[id].visible = value
	var header: Button = category_buttons[id]
	header.set_pressed_no_signal(value)
	header.text = ("▾  " if value else "▸  ") + str(header.get_meta("title"))
	header.tooltip_text = "Collapse tools" if value else "Expand tools"
	_fit.call_deferred()

func _fit() -> void:
	update_minimum_size()
	var height := get_combined_minimum_size().y
	size = Vector2(get_combined_minimum_size().x, height)
	offset_bottom = _bottom
	offset_top = _bottom - height

func set_available_tools(ids: Array[StringName]) -> void:
	_supported = ids.duplicate()
	_availability_known = true
	_refresh_availability()

func _refresh_availability() -> void:
	for id in buttons:
		var button: Button = buttons[id]
		button.disabled = not Engine.is_editor_hint() and (not _availability_known or id not in _supported)
		button.tooltip_text = button.definition.tooltip
		if button.disabled:
			button.tooltip_text += "\nNo construction handler registered for '" + str(id) + "'."
	if not buttons.has(selected_tool) or buttons[selected_tool].disabled:
		var fallback: StringName = &""
		for id in buttons:
			if not buttons[id].disabled:
				fallback = id
				break
		select_tool(fallback)
	else:
		select_tool(selected_tool)

func select_tool(id: StringName) -> void:
	if id != &"" and (not buttons.has(id) or buttons[id].disabled):
		return
	for key in buttons:
		buttons[key].set_pressed_no_signal(key == id)
	if selected_tool != id:
		selected_tool = id
		tool_selected.emit(id)

func _resource_changed() -> void:
	_dirty = true

func _watch(resource: Resource) -> void:
	if resource != null and resource not in _observed:
		_observed.append(resource)
		resource.changed.connect(_resource_changed)

func _disconnect_resources() -> void:
	for resource in _observed:
		resource.changed.disconnect(_resource_changed)
	_observed.clear()

func _exit_tree() -> void:
	_disconnect_resources()
