extends Node2D

const RoundedInk = preload("res://floors/rounded_ink.gd")

const FloorData = preload("res://floors/floor_data.gd")
@export var paint_preview_color := Color(0.32, 0.55, 0.44, 0.24)
@export var erase_preview_color := Color(0.72, 0.34, 0.28, 0.24)
@export var erase_preview_ink := Color(0.72, 0.28, 0.22, 0.9)
@export var preview_ink := Color(0.24, 0.34, 0.29, 0.8)
@export_range(0.5, 24.0, 0.1) var preview_width := 3.5
@export_group("Preview Guides")
@export var show_preview_guides := true
@export var guide_color := Color(0.24, 0.34, 0.29, 0.8)
@export_range(0.5, 8.0, 0.1) var guide_width := 1.0
@export_range(1.0, 12.0, 0.5) var guide_marker_radius := 3.0
@export_range(10, 32, 1) var guide_font_size := 14
var data:
	get:
		return get_parent().get_node("WorldModel").floors
@export var tool_handlers: Array[ConstructionToolHandler] = []
var tool: StringName = &""
var handlers: Dictionary = {}
var menu: Control
var enabled := true
var raw_start := Vector2.ZERO
var current_proposal: ConstructionProposal
var dragging := false
var erasing := false
var step_cells := 1
var start := Vector2i.ZERO
var endpoint := Vector2i.ZERO
var control_points: Array=[]
var raw_points: Array=[]
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
	var hint=get_parent().get_node_or_null("CanvasLayer/FloorHint")
	if hint!=null:hint.text=handlers[tool].instructions() if handlers.has(tool) else "Select a construction tool"

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

func make_proposal(a: Vector2i,b: Vector2i,erase: bool) -> ConstructionProposal:
	var context := construction_context()
	var gesture := ConstructionGesture.new()
	gesture.start=a;gesture.end=b;gesture.step=step_cells;gesture.erase=erase
	gesture.raw_start=raw_start if dragging else Vector2(a)
	gesture.raw_end=context.pointer_base if dragging else Vector2(b)
	gesture.control_points=control_points.duplicate()
	gesture.raw_points=raw_points.duplicate()
	gesture.alternate=Input.is_physical_key_pressed(KEY_SHIFT)
	if gesture.control_points.size()<handlers[tool].control_point_count():
		gesture.control_points.append(b);gesture.raw_points.append(gesture.raw_end)
	return handlers[tool].propose_edit(context,gesture)

func commit_stroke(a: Vector2i,b: Vector2i,erase: bool) -> void:
	if handlers.has(tool):
		var proposal=make_proposal(a,b,erase)
		if proposal.valid:construction_context().model.execute(proposal.command)

func set_enabled(value: bool) -> void:
	enabled=value
	if not value:cancel()

func cancel() -> void:
	dragging = false
	control_points.clear();raw_points.clear()
	current_proposal=null
	if is_instance_valid(_preview_ink):
		_preview_ink.configure([], 1.0, Color.WHITE)
	if is_instance_valid(camera):
		camera.construction_active = false
	queue_redraw()

func _process(_delta: float) -> void:
	if dragging:
		endpoint = snap(get_global_mouse_position())
		current_proposal=make_proposal(start,endpoint,erasing)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and handlers.has(tool) and handlers[tool].control_point_count()>2:
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				if get_viewport().gui_get_hovered_control()!=null:
					cancel();return
				if event.button_index!=(MOUSE_BUTTON_RIGHT if erasing else MOUSE_BUTTON_LEFT):
					cancel();get_viewport().set_input_as_handled();return
				advance_control_point(snap(get_global_mouse_position()),get_global_mouse_position()/grid.base_cell_size)
			elif get_viewport().gui_get_hovered_control()!=null:cancel()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == (MOUSE_BUTTON_RIGHT if erasing else MOUSE_BUTTON_LEFT):
		# Releasing over UI cancels rather than painting underneath it.
		if get_viewport().gui_get_hovered_control() == null:
			endpoint = snap(get_global_mouse_position())
			commit_stroke(start, endpoint, erasing)
		cancel()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or dragging or not handlers.has(tool):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if Input.is_physical_key_pressed(KEY_SPACE) or camera._drag_button != 0:
			return
		var step=visible_step() if handlers[tool].snap_policy()==&"visible_grid" else 1
		step_cells=step
		begin_gesture(snap(get_global_mouse_position()),event.button_index==MOUSE_BUTTON_RIGHT,get_global_mouse_position()/grid.base_cell_size,step)
		get_viewport().set_input_as_handled()

func begin_gesture(point: Vector2i,remove: bool,raw: Vector2,step: int) -> void:
	current_proposal=null
	dragging=true;erasing=remove;step_cells=step;raw_start=raw
	start=point;endpoint=point;control_points=[point];raw_points=[raw]
	camera.construction_active=true;camera._target_zoom=camera.zoom.x

func advance_control_point(point: Vector2i,raw: Vector2) -> void:
	if not dragging or not handlers.has(tool):return
	control_points.append(point);raw_points.append(raw);endpoint=point;current_proposal=null
	if control_points.size()>=handlers[tool].control_point_count():
		# The clicked raw position is authoritative, not the next frame's pointer.
		var gesture:=ConstructionGesture.new()
		gesture.start=start;gesture.end=endpoint;gesture.step=step_cells;gesture.erase=erasing
		gesture.control_points=control_points.duplicate();gesture.raw_points=raw_points.duplicate()
		gesture.raw_start=raw_start;gesture.raw_end=raw;gesture.alternate=Input.is_physical_key_pressed(KEY_SHIFT)
		var proposal=handlers[tool].propose_edit(construction_context(),gesture)
		if proposal.valid:construction_context().model.execute(proposal.command)
		cancel()
	queue_redraw()

func _draw() -> void:
	if not dragging:
		return
	var color := erase_preview_color if erasing else paint_preview_color
	var ink := erase_preview_ink if erasing else preview_ink
	if not handlers.has(tool):
		return
	if current_proposal==null:current_proposal=make_proposal(start,endpoint,erasing)
	var geometry: Dictionary=current_proposal.preview
	if not current_proposal.valid and not geometry.get("pending",false):
		color=erase_preview_color;ink=erase_preview_ink
	for polygon in geometry.get("fills", []):
		draw_colored_polygon(polygon, color)
	var width: float = renderer.line_width if geometry.get("use_line_width", false) else preview_width
	_preview_ink.configure(geometry.get("paths", []), geometry.get("world_width",width / camera.zoom.x), ink, geometry.get("closed", false))
	if show_preview_guides:
		var scale := maxf(camera.zoom.x, 0.0001)
		var tint := erase_preview_ink if erasing else guide_color
		for guide in geometry.get("guides", []):
			draw_polyline(guide, tint, guide_width / scale, true)
		for marker in geometry.get("markers", PackedVector2Array()):
			draw_circle(marker, guide_marker_radius / scale, tint, true, -1, true)
		if geometry.has("label"):
			# Transform the font with the canvas, compensating only for camera zoom.
			var font: Font = ThemeDB.fallback_font
			var label_position: Vector2 = geometry.get("label_position", Vector2.ZERO)
			draw_set_transform(label_position + Vector2(10, -10) / scale, 0, Vector2.ONE / scale)
			draw_string(font, Vector2.ZERO, geometry["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, guide_font_size, tint)
			draw_set_transform(Vector2.ZERO)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel()

func construction_context() -> ConstructionContext:
	var context := ConstructionContext.new()
	context.model = get_parent().get_node("WorldModel")
	context.cell_size = grid.base_cell_size
	context.camera_scale = camera.zoom.x
	context.pointer_base = get_global_mouse_position() / context.cell_size
	context.corner_radius_world = minf(renderer.corner_radius / camera.zoom.x, grid.base_cell_size * 0.45)
	return context
