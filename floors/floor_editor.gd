extends Node2D

const RoundedInk = preload("res://floors/rounded_ink.gd")

const FloorData = preload("res://floors/floor_data.gd")
@export var paint_preview_color := Color(0.32, 0.55, 0.44, 0.24)
@export var erase_preview_color := Color(0.72, 0.34, 0.28, 0.24)
@export var erase_preview_ink := Color(0.72, 0.28, 0.22, 0.9)
@export var preview_ink := Color(0.24, 0.34, 0.29, 0.8)
@export_range(0.5, 24.0, 0.1) var preview_width := 3.5
var data := FloorData.new()
@export var tool_handlers: Array[ConstructionToolHandler] = []
var tool: StringName = &""
var handlers: Dictionary = {}
var menu: Control
var dragging := false
var erasing := false
var step_cells := 1
var start := Vector2i.ZERO
var endpoint := Vector2i.ZERO
@onready var grid = get_parent().get_node("GridRenderer")
@onready var camera = get_parent().get_node("Camera2D")
@onready var renderer = get_parent().get_node("FloorRenderer")
var _preview_ink: CanvasGroup

func _ready() -> void:
	_preview_ink = RoundedInk.new()
	_preview_ink.name = "PreviewInk"
	add_child(_preview_ink)
	# The menu may be later in the scene tree: wait until its children exist.
	call_deferred("_connect_tools")
	renderer.data = data
	renderer.grid = grid

func _connect_tools() -> void:
	menu = get_parent().get_node_or_null("CanvasLayer/ConstructionMenu")
	if menu == null:
		push_error("Add ConstructionMenu under the world's CanvasLayer.")
		return
	if not menu.tool_selected.is_connected(select_tool):
		menu.tool_selected.connect(select_tool)
	for handler in tool_handlers:
		register_handler(handler)
	_sync_available_tools()
	select_tool(menu.selected_tool)

func register_handler(handler: ConstructionToolHandler) -> bool:
	if handler == null or handler.tool_id == &"" or handlers.has(handler.tool_id):
		push_warning("Construction handlers need unique, nonempty IDs.")
		return false
	handlers[handler.tool_id] = handler
	_sync_available_tools()
	return true

func unregister_handler(id: StringName) -> void:
	handlers.erase(id)
	_sync_available_tools()

func _sync_available_tools() -> void:
	if is_instance_valid(menu):
		var ids: Array[StringName] = []
		ids.assign(handlers.keys())
		menu.set_available_tools(ids)

func select_tool(value: StringName) -> void:
	if is_instance_valid(menu) and menu.selected_tool != value:
		menu.select_tool(value)
		return
	if value != &"" and not handlers.has(value):
		return
	if tool != value:
		cancel()
		tool = value

func visible_step() -> int:
	var base_pixels: float = maxf(grid.base_cell_size, 1.0) * camera.zoom.x
	var multiplier: int = maxi(grid.level_step_count, 2)
	var detail: float = maxf(0.0, log(maxf(grid.target_screen_spacing, 8.0) / base_pixels) / log(float(multiplier)))
	var level := floori(detail)
	var blend := smoothstep(1.0 - clampf(grid.fade_range, 0.05, 1.0), 1.0, fposmod(detail, 1.0))
	if blend >= 0.5:
		level += 1
	return int(pow(float(multiplier), level))

func snap(point: Vector2) -> Vector2i:
	return Vector2i((point / (maxf(grid.base_cell_size, 1.0) * step_cells)).round()) * step_cells

func commit_stroke(a: Vector2i, b: Vector2i, erase: bool) -> void:
	if handlers.has(tool):
		handlers[tool].commit(data, a, b, step_cells, erase)

func cancel() -> void:
	dragging = false
	if is_instance_valid(_preview_ink):
		_preview_ink.configure([], 1.0, Color.WHITE)
	if is_instance_valid(camera):
		camera.construction_active = false
	queue_redraw()

func _process(_delta: float) -> void:
	if dragging:
		endpoint = snap(get_global_mouse_position())
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == (MOUSE_BUTTON_RIGHT if erasing else MOUSE_BUTTON_LEFT):
		# Releasing over UI cancels rather than painting underneath it.
		if get_viewport().gui_get_hovered_control() == null:
			endpoint = snap(get_global_mouse_position())
			commit_stroke(start, endpoint, erasing)
		cancel()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if dragging or not handlers.has(tool):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if Input.is_physical_key_pressed(KEY_SPACE) or camera._drag_button != 0:
			return
		dragging = true
		erasing = event.button_index == MOUSE_BUTTON_RIGHT
		step_cells = visible_step()
		start = snap(get_global_mouse_position())
		endpoint = start
		camera.construction_active = true
		camera._target_zoom = camera.zoom.x
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if not dragging:
		return
	var color := erase_preview_color if erasing else paint_preview_color
	var ink := erase_preview_ink if erasing else preview_ink
	if not handlers.has(tool):
		return
	var geometry: Dictionary = handlers[tool].preview_geometry(start, endpoint, step_cells, grid.base_cell_size, minf(renderer.corner_radius / camera.zoom.x, grid.base_cell_size * 0.45))
	for polygon in geometry.get("fills", []):
		draw_colored_polygon(polygon, color)
	var width: float = renderer.line_width if geometry.get("use_line_width", false) else preview_width
	_preview_ink.configure(geometry.get("paths", []), width / camera.zoom.x, ink, geometry.get("closed", false))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel()
