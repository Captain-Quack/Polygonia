extends Node2D
## Scene adapter: fixed-step clock, drawing, and read-only agent inspection.
var paused := false
var speed := 1.0
const SIMULATION_STEP := 0.1
var accumulator := 0.0
var selected_id := 0
var inspecting := false
var inspect_button: CheckButton
var description: Label
var clock_label: Label
var _inspection_elapsed := 0.0
var _triangle = AgentRenderer.rounded_triangle(1.0)
var _remains = PackedVector2Array([Vector2(.9,0),Vector2(.25,.24),Vector2(-.4,.85),Vector2(-.3,.15),Vector2(-.75,-.6),Vector2(-.05,-.3),Vector2(.35,-.65),Vector2(.3,-.08)])
@onready var model: WorldModel = get_parent().get_node("WorldModel")
@onready var grid = get_parent().get_node("GridRenderer")
@onready var editor = get_parent().get_node("ConstructionPreview")
@onready var space_inspector = get_parent().get_node("SpatialInspector")
func _ready() -> void:
	call_deferred("_build_controls")
func _build_controls() -> void:
	var box = space_inspector.content
	box.add_child(HSeparator.new())
	var row = HBoxContainer.new(); box.add_child(row)
	var pause = Button.new(); pause.text = "Pause"; row.add_child(pause)
	pause.pressed.connect(func(): paused = not paused; pause.text = "Resume" if paused else "Pause")
	var rate = OptionButton.new(); row.add_child(rate)
	for label in ["1×","2×","4×"]: rate.add_item(label)
	rate.item_selected.connect(func(index): speed = [1.0,2.0,4.0][index])
	clock_label = Label.new(); row.add_child(clock_label)
	var blood = CheckButton.new(); blood.text = "Blood effects"; blood.button_pressed = model.simulation.gore.enabled
	blood.toggled.connect(func(value): model.simulation.gore.enabled = value)
	box.add_child(blood)
	blood.add_theme_color_override("font_color",Color(.2,.28,.25))
	inspect_button = CheckButton.new(); inspect_button.text = "Inspect Polygon"; box.add_child(inspect_button)
	inspect_button.toggled.connect(_set_inspecting)
	space_inspector.mode.toggled.connect(func(on):
		if on: _set_inspecting(false))
	get_parent().get_node("CanvasLayer/ConstructionMenu").tool_selected.connect(func(_tool): _set_inspecting(false))
	description = Label.new(); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	for control in [clock_label,description,inspect_button]: control.add_theme_color_override("font_color",Color(.2,.28,.25))
	space_inspector._disable_scroll_pass(space_inspector.panel)
	_refresh()
func _set_inspecting(value: bool) -> void:
	# Inspection suspends construction selection; clicking any tool resumes it.
	if value: editor.menu.select_tool(&"")
	inspecting = value; inspect_button.set_pressed_no_signal(value)
	if value: space_inspector.leave_inspect_mode()
	editor.set_enabled(not value and not space_inspector.inspecting)
func _process(delta: float) -> void:
	if not paused:
		accumulator = minf(accumulator + delta*speed,0.8)
		while accumulator >= SIMULATION_STEP:
			model.simulation.tick(SIMULATION_STEP); accumulator -= SIMULATION_STEP
	_inspection_elapsed += delta
	if _inspection_elapsed >= .2:
		_inspection_elapsed = 0.0
		_refresh()
	queue_redraw()
func _refresh() -> void:
	if description == null: return
	var sim: AgentSimulation = model.simulation
	clock_label.text = "%ds" % int(sim.time)
	description.text = "Place Polygons, food and resting places
using the Life tools. Inspect a Polygon
to see its needs and decisions."
	var agent=sim.get_agent(selected_id)
	if agent!=null:
		var choices: Array[String] = []
		for option in agent.decision_scores.slice(0,3):
			choices.append("%s %.2f" % [option.get("interaction",option.kind),option.score])
		description.text = agent.inspection_text()+"\n"+" / ".join(choices)+"\n"+(agent.recent_events[-1] if not agent.recent_events.is_empty() else "Observing the world.")+AgentCognition.inspection(agent,sim.time)
		return
func _unhandled_input(event: InputEvent) -> void:
	if not inspecting: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_set_inspecting(false); get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_physical_key_pressed(KEY_SPACE): return
		var point = get_global_mouse_position()/grid.base_cell_size
		selected_id = 0
		var best = 0.6
		for agent in model.simulation.agents:
			if agent.death_handled: continue
			var distance = point.distance_to(agent.motion.sample(accumulator / SIMULATION_STEP).position)
			if distance < best: selected_id = agent.id; best = distance
		get_viewport().set_input_as_handled(); _refresh()
func _draw() -> void:
	if not is_instance_valid(model): return
	var cell: float = grid.base_cell_size
	for object in model.simulation.objects.all():
		var p: Vector2 = object.position*cell
		var color: Color = object.definition.color
		var available := false
		for provider in object.providers:
			if provider.stock != 0: available = true
		if not available: color.a = 0.25
		# Object visuals can be replaced independently of interaction providers.
		if object.definition.definition_id == &"rest":
			draw_style_box(_rest_style(color),Rect2(p-Vector2(.3,.18)*cell,Vector2(.6,.36)*cell))
		elif object.definition.definition_id == &"corpse":
			draw_set_transform(p)
			draw_set_transform(p,0,Vector2.ONE*.2*cell)
			draw_colored_polygon(_remains,Color(.6,.38,.34,.9))
			draw_line(Vector2(-.35,-.1),Vector2(.4,.12),Color(.92,.75,.59),.18,true)
			draw_circle(Vector2(-.2,.18),.15,Color(.8,.6,.45))
			draw_set_transform(Vector2.ZERO)
		else:
			# Keep an admitted meal beside its eater so small shared piles stay visible.
			var anchor = p
			for provider in object.providers:
				if provider is FoodInteractionProvider and provider.claimed(): anchor += Vector2(0,-.34)*cell; break
			for offset in FoodVisuals.offsets(FoodVisuals.count(object)):
				draw_circle(anchor+offset*cell,.085*cell,color,true,-1,true)
	for agent in model.simulation.agents:
		if agent.death_handled: continue
		var pose = agent.motion.sample(accumulator / SIMULATION_STEP)
		var feedback = model.simulation.gore.appearance(agent.id,maxf(0,model.simulation.gore.time-.1+accumulator))
		var squash = Vector2(1-.25*feedback.flash-.1*feedback.bite,1+.18*feedback.flash+.1*feedback.bite)
		draw_set_transform(pose.position*cell,pose.facing+feedback.bite*.12,squash*agent.radius*cell)
		var color = AgentRenderer.state_color(agent).lerp(Color(.85,.05,.045),feedback.flash*.8)
		draw_colored_polygon(_triangle,color)
		if feedback.blood > 0:
			draw_colored_polygon(PackedVector2Array([Vector2(.73,0),Vector2(.05,-.25),Vector2(.12,.28)]),Color(.43,.02,.035,feedback.blood*.85))
			if feedback.blood > .5: draw_circle(Vector2(-.25,.25),.15,Color(.48,.025,.04,.7))
		var outline = _triangle.duplicate(); outline.append(outline[0])
		draw_polyline(outline,Color(.16,.23,.21),1.4/(agent.radius*cell),true)
		draw_set_transform(Vector2.ZERO)
		if agent.id == selected_id:
			draw_circle(pose.position*cell,.32*cell,Color(.3,.55,.45),false,1.5,true)
			var path = PackedVector2Array([pose.position*cell])
			for point in agent.controller.route_points: path.append(point*cell)
			if path.size()>1: draw_polyline(path,Color(.3,.55,.45,.4),1.0,true)
func _rest_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color = Color(color,.25); style.border_color = color
	style.set_border_width_all(2); style.set_corner_radius_all(8)
	return style

