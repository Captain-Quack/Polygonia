extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var model = world.get_node("WorldModel")
	check(world.has_node("SurvivalView"),"survival integrated into main scene")
	if not world.has_node("SurvivalView"): world.queue_free(); quit(1); return
	var editor = world.get_node("ConstructionPreview")
	for id in [&"agent",&"food",&"rest",&"move_object"]:
		check(editor.handlers.has(id),"registered modular tool %s" % id)
	editor.select_tool(&"food"); editor.commit_stroke(Vector2i.ZERO,Vector2i.ZERO,false)
	check(model.simulation.objects.all().size() == 1,"food placement command")
	editor.select_tool(&"agent"); editor.commit_stroke(Vector2i(1,0),Vector2i(1,0),false)
	check(model.simulation.agents.size() == 1,"agent placement command")
	editor.select_tool(&"move_object"); editor.commit_stroke(Vector2i.ZERO,Vector2i(3,0),false)
	check(model.simulation.objects.all()[0].position == Vector2(3.5,0.5),"resource move keeps identity")
	editor.select_tool(&"food"); editor.commit_stroke(Vector2i(3,0),Vector2i(3,0),true)
	check(model.simulation.objects.all().is_empty(),"resource erase command")
	var view = world.get_node("SurvivalView")
	# Exercise real pointer snapping rather than only pre-snapped commands.
	editor.select_tool(&"food")
	var center = Vector2(0.5,0.5) * world.get_node("GridRenderer").base_cell_size
	check(editor.snap(center) == Vector2i.ZERO,"food center resolves to its containing cell")
	editor.commit_stroke(Vector2i.ZERO,Vector2i.ZERO,false)
	var clicked = editor.snap(center)
	editor.commit_stroke(clicked,clicked,true)
	check(model.simulation.objects.all().is_empty(),"clicking rendered center removes food")
	editor.commit_stroke(Vector2i.ZERO,Vector2i.ZERO,false)
	editor.select_tool(&"move_object")
	clicked = editor.snap(center)
	check(editor.make_proposal(clicked,Vector2i(2,0),false).valid,"move can grab rendered object center")
	editor.select_tool(&"food")
	view._set_inspecting(true)
	editor.menu.buttons[&"food"].pressed.emit()
	check(not view.inspecting and editor.enabled,"same construction tool exits agent inspection")
	view.paused = true
	var before = model.simulation.time
	view._process(1.0)
	check(model.simulation.time == before,"pause freezes body and actions")
	var selected=model.simulation.agents[0]
	selected.memory.record(&"received",selected.position,model.simulation.time,99,1)
	view.selected_id=selected.id; view._refresh()
	check("Experience:" in view.description.text and "Polygon 99" in view.description.text,"selected agent inspection exposes its actual remembered experience")
	root.size=Vector2i(800,480)
	await process_frame; await process_frame
	var panel=world.get_node("SpatialInspector").panel
	check(panel.get_global_rect().end.y<=root.size.y and panel.size.y>100,"long history inspection stays inside a small viewport")
	var scroll=panel.get_child(0) as ScrollContainer
	check(scroll!=null and scroll.get_v_scroll_bar().max_value>scroll.size.y,"long inspection can be scrolled without enlarging the panel")
	world.queue_free(); await process_frame
	print("survival_tools: %d failures" % failures); quit(1 if failures else 0)

