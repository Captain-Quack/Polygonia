extends Node2D
## Development view of physical facts, never social meaning or ownership.
var inspecting:=false
var selected_door_id:=0
var selected_region_id:=-1
var selected_point:=Vector2.ZERO
var has_selection:=false
var overlay:=false
var probing:=false
var probe_visible:=false
var probe_start:=Vector2.ZERO
var probe_end:=Vector2.ZERO
var panel: PanelContainer
var description: Label
var mode: CheckButton
var open_button: Button
var lock_button: Button
var probe_label: Label
var feedback: Label
@onready var model: WorldModel=get_parent().get_node("WorldModel")
@onready var editor=get_parent().get_node("ConstructionPreview")
@onready var grid=get_parent().get_node("GridRenderer")
@onready var camera=get_parent().get_node("Camera2D")
func _ready() -> void:
	var host=get_parent().get_node("CanvasLayer/Inspector")
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel=PanelContainer.new();panel.name="SpacePanel";host.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.96,.95,.90,.96)
	style.set_corner_radius_all(8);style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=10;style.content_margin_bottom=12
	panel.add_theme_stylebox_override("panel",style)
	panel.add_theme_color_override("font_color",Color(.2,.28,.25))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",7);panel.add_child(box)
	var title:=Label.new();title.text="Spaces & doors";box.add_child(title)
	mode=CheckButton.new();mode.text="Inspect / operate";box.add_child(mode)
	mode.toggled.connect(func(on):
		if on:enter_inspect_mode()
		else:leave_inspect_mode())
	var regions_toggle:=CheckButton.new();regions_toggle.text="Show structural regions";box.add_child(regions_toggle)
	regions_toggle.toggled.connect(func(on):overlay=on;queue_redraw())
	description=Label.new();description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(description)
	var row:=HBoxContainer.new();box.add_child(row)
	open_button=Button.new();open_button.text="Open";row.add_child(open_button)
	lock_button=Button.new();lock_button.text="Lock";row.add_child(lock_button)
	open_button.pressed.connect(func():
		var d=model.structures.get_door(selected_door_id)
		if not d.is_empty():operate(&"CLOSE" if d.state==&"OPEN" else &"OPEN"))
	lock_button.pressed.connect(func():
		var d=model.structures.get_door(selected_door_id)
		if not d.is_empty():operate(&"UNLOCK" if d.locked else &"LOCK"))
	feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(feedback)
	probe_label=Label.new();probe_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(probe_label)
	for child in [title,description,feedback,probe_label,mode,regions_toggle]:child.add_theme_color_override("font_color",Color(.2,.28,.25))
	_disable_scroll_pass(panel)
	model.structure_changed.connect(_changed)
	model.world_replaced.connect(_changed)
	get_viewport().size_changed.connect(_layout)
	call_deferred("_connect_menu")
	_layout();_refresh()
func _disable_scroll_pass(control: Control) -> void:
	control.mouse_force_pass_scroll_events=false
	for child in control.get_children():
		if child is Control:_disable_scroll_pass(child)
func _layout() -> void:
	var width=minf(330,maxf(200,get_viewport_rect().size.x-32))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left=-width-20;panel.offset_right=-20;panel.offset_top=20
	panel.custom_minimum_size.x=width
func _connect_menu() -> void:
	var menu=get_parent().get_node("CanvasLayer/ConstructionMenu")
	menu.tool_selected.connect(func(_tool):leave_inspect_mode())
func enter_inspect_mode() -> void:
	inspecting=true;mode.set_pressed_no_signal(true);editor.set_enabled(false);_refresh()
func leave_inspect_mode() -> void:
	inspecting=false;probing=false;mode.set_pressed_no_signal(false);editor.set_enabled(true);_refresh()
func select_at(point_base: Vector2) -> void:
	selected_point=point_base;has_selection=true;selected_door_id=0
	var distance=10.0/(grid.base_cell_size*camera.zoom.x)
	for d in model.structures.get_doors():
		var path=StructureData.door_path(d);var candidate=INF
		for i in range(path.size()-1):
			var p=Geometry2D.get_closest_point_to_segment(point_base,path[i],path[i+1])
			candidate=minf(candidate,point_base.distance_to(p))
		if candidate<distance:
			distance=candidate;selected_door_id=d.id
	selected_region_id=model.regions.locate(point_base).region_id
	feedback.text="";_refresh();queue_redraw()
func operate(action: StringName) -> StructureChange:
	var result=model.execute(StructureCommand.door_action(selected_door_id,action))
	feedback.text="" if result.accepted else str(result.reason).replace("_"," ").capitalize()
	_refresh();return result
func _changed(_change) -> void:
	if selected_door_id!=0 and model.structures.get_door(selected_door_id).is_empty():selected_door_id=0
	if has_selection:selected_region_id=model.regions.locate(selected_point).region_id
	_refresh();queue_redraw()
func _refresh() -> void:
	open_button.visible=false;lock_button.visible=false
	probe_label.text="Inspect: click a space or door.\nShift-drag: test sight and a body of radius 0.2 cells."
	var d=model.structures.get_door(selected_door_id)
	if not d.is_empty():
		description.text="Door %d · %s%s\nCoverage: Unknown"%[d.id,str(d.state).capitalize()," · Locked" if d.locked else ""]
		open_button.visible=inspecting;lock_button.visible=inspecting
		open_button.text="Close" if d.state==&"OPEN" else "Open";open_button.disabled=d.locked
		lock_button.text="Unlock" if d.locked else "Lock";lock_button.disabled=d.state==&"OPEN"
	elif has_selection:
		var r=model.regions.region(selected_region_id)
		if r.is_empty():description.text="Boundary\nCoverage: Unknown"
		elif r.bounded:description.text="Region %d · Enclosed\nArea: %s cells² · Entrances: %d\nCoverage: Unknown"%[r.id,str(r.area),r.portal_ids.size()]
		else:description.text="Exterior · Unbounded\nCoverage: Unknown\nOutdoor places can acquire meaning through use."
	else:description.text="Physical boundaries and entrances.\nCoverage: Unknown"
func _unhandled_input(event: InputEvent) -> void:
	if not inspecting:return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if Input.is_physical_key_pressed(KEY_SPACE) or camera._drag_button!=0:return
		var p=get_global_mouse_position()/grid.base_cell_size
		if event.shift_pressed:
			probing=true;probe_visible=true;probe_start=p;probe_end=p
		else:select_at(p)
		get_viewport().set_input_as_handled()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and inspecting:
		leave_inspect_mode();get_viewport().set_input_as_handled()
	if probing and event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if get_viewport().gui_get_hovered_control()!=null:probe_visible=false
		probing=false;get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
	if probing:probe_end=get_global_mouse_position()/grid.base_cell_size
	if probe_visible:
		var body=model.physical.sweep(probe_start,probe_end,.2)
		var sight=model.physical.visibility_hits(probe_start,probe_end)
		probe_label.text="Probe · body: %s · sight: %s\nShift-drag to move probe."%["blocked" if body.get("hit",false) else "clear","clear" if sight.is_empty() else "blocked"]
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(model):return
	var cell: float=grid.base_cell_size
	if overlay:
		for r in model.regions.get_regions():
			if not r.bounded:continue
			var color=Color.from_hsv(fposmod(r.id*.618,1),.4,.65,.16)
			var loops: Array=[]
			for ring in [r.outer]+r.holes:
				var points:=PackedVector2Array()
				for point in ring:points.append(Vector2(point)*cell)
				loops.append(points)
			for band in preload("res://floors/shape_geometry.gd").fill_bands(loops):
				var origin=band[0];var local=band.duplicate()
				for i in range(local.size()):local[i]-=origin
				draw_set_transform(origin);draw_colored_polygon(local,color);draw_set_transform(Vector2.ZERO)

		for portal in model.regions.get_portals():
			var p=(Vector2(portal.a)+Vector2(portal.b))*.5*cell
			draw_circle(p,.11*cell,Color(.2,.5,.6,.9))
	if selected_door_id!=0:
		var d=model.structures.get_door(selected_door_id)
		if not d.is_empty():draw_circle((Vector2(d.a)+Vector2(d.b))*.5*cell,.3*cell,Color(.3,.6,.5),false,1.5/camera.zoom.x,true)
	if probe_visible:
		draw_line(probe_start*cell,probe_end*cell,Color(.7,.3,.2,.8),2/camera.zoom.x,true)
		draw_circle(probe_end*cell,.2*cell,Color(.7,.3,.2,.3))
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:probing=false
