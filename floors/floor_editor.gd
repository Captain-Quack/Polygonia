extends Node2D

const RoundedInk = preload("res://floors/rounded_ink.gd")
const Geometry = preload("res://floors/shape_geometry.gd")
const FloorData = preload("res://floors/floor_data.gd")
@export var paint_preview_color := Color(0.32, 0.55, 0.44, 0.24)
@export var erase_preview_color := Color(0.72, 0.34, 0.28, 0.24)
@export var erase_preview_ink := Color(0.72, 0.28, 0.22, 0.9)
@export var preview_ink := Color(0.24, 0.34, 0.29, 0.8)
@export_range(0.5, 24.0, 0.1) var preview_width := 3.5
var data := FloorData.new()
var tool := 0
var dragging := false
var erasing := false
var step_cells := 1
var start := Vector2i.ZERO
var endpoint := Vector2i.ZERO
var preview := Rect2i()
@onready var grid = get_parent().get_node("GridRenderer")
@onready var camera = get_parent().get_node("Camera2D")
@onready var renderer = get_parent().get_node("FloorRenderer")
var _preview_ink: CanvasGroup
var line_button: Button
var square_button: Button

func _ready() -> void:
	_preview_ink = RoundedInk.new()
	_preview_ink.name = "PreviewInk"
	add_child(_preview_ink)
	# The menu may be later in the scene tree: wait until its children exist.
	call_deferred("_connect_tools")
	renderer.data = data
	renderer.grid = grid

func _connect_tools() -> void:
	var menu = get_parent().get_node_or_null("CanvasLayer/ConstructionMenu")
	if menu != null:
		line_button = menu.line_button
		square_button = menu.square_button
	else:
		# Keeps the previous toolbar functional while applying the scene migration.
		line_button = get_parent().get_node_or_null("CanvasLayer/FloorTools/Line")
		square_button = get_parent().get_node_or_null("CanvasLayer/FloorTools/Square")
	if line_button == null or square_button == null:
		push_error("Add ConstructionMenu under the world's CanvasLayer and attach construction_menu.gd.")
		return
	renderer.data = data
	renderer.grid = grid
	line_button.pressed.connect(select_tool.bind(0))
	square_button.pressed.connect(select_tool.bind(1))
	select_tool(0)

func select_tool(value: int) -> void:
	cancel()
	tool = value
	if is_instance_valid(line_button):
		line_button.button_pressed = tool == 0
	if is_instance_valid(square_button):
		square_button.button_pressed = tool == 1

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

func shape(a: Vector2i, b: Vector2i, _mode: int, step: int) -> Rect2i:
	return Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), Vector2i(maxi(absi(b.x - a.x), step), maxi(absi(b.y - a.y), step)))

func line_endpoint(a: Vector2i, b: Vector2i) -> Vector2i:
	var difference := b - a
	return Vector2i(b.x, a.y) if absi(difference.x) >= absi(difference.y) else Vector2i(a.x, b.y)

func commit_stroke(a: Vector2i, b: Vector2i, erase: bool) -> void:
	if tool == 0:
		data.apply_line(a, line_endpoint(a, b), erase)
	else:
		data.apply_rect(shape(a, b, 1, step_cells), erase)

func cancel() -> void:
	dragging = false
	if is_instance_valid(_preview_ink):
		_preview_ink.configure([], 1.0, Color.WHITE)
	preview = Rect2i()
	if is_instance_valid(camera):
		camera.construction_active = false
	queue_redraw()

func _process(_delta: float) -> void:
	if dragging:
		endpoint = snap(get_global_mouse_position())
		preview = shape(start, endpoint, tool, step_cells)
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
	if dragging:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if Input.is_physical_key_pressed(KEY_SPACE) or camera._drag_button != 0:
			return
		dragging = true
		erasing = event.button_index == MOUSE_BUTTON_RIGHT
		step_cells = visible_step()
		start = snap(get_global_mouse_position())
		endpoint = start
		preview = shape(start, endpoint, tool, step_cells)
		camera.construction_active = true
		camera._target_zoom = camera.zoom.x
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if not dragging:
		return
	var color := erase_preview_color if erasing else paint_preview_color
	var ink := erase_preview_ink if erasing else preview_ink
	if tool == 0:
		var points := PackedVector2Array([Vector2(start) * grid.base_cell_size, Vector2(line_endpoint(start, endpoint)) * grid.base_cell_size])
		_preview_ink.configure([points], renderer.line_width / camera.zoom.x, ink)
		return
	var rect := Rect2(Vector2(preview.position) * grid.base_cell_size, Vector2(preview.size) * grid.base_cell_size)
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var rounded := Geometry.rounded_loop(points, minf(renderer.corner_radius / camera.zoom.x, grid.base_cell_size * 0.45))
	draw_colored_polygon(rounded, color)
	_preview_ink.configure([rounded], preview_width / camera.zoom.x, ink, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel()
