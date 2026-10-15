extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world=load("res://world/world.tscn").instantiate();root.add_child(world)
	for i in range(5):await process_frame
	var editor=world.get_node("ConstructionPreview");var model=world.get_node("WorldModel")
	check(editor.handlers.has(&"arc_wall") and not editor.menu.buttons.has(&"circular_wall"),"Arc Wall replaces Circular Wall")
	if not editor.handlers.has(&"arc_wall"):
		world.queue_free();await process_frame;quit(1);return
	var handler=editor.handlers[&"arc_wall"]
	check(handler.control_point_count()==3,"arc is a three-point gesture")
	var gesture=ConstructionGesture.new()
	gesture.control_points=[Vector2i.ZERO,Vector2i(5,0),Vector2i(0,5)]
	gesture.start=Vector2i.ZERO;gesture.end=Vector2i(0,5);gesture.raw_end=Vector2(0,5)
	var context=editor.construction_context()
	var quarter=handler.propose_edit(context,gesture)
	check(quarter.valid,"quarter arc preview valid")
	model.execute(quarter.command)
	check(model.regions.get_regions().size()==1,"arc does not close imaginary chord")
	check(not model.physical.sweep(Vector2.ZERO,Vector2(-6,0),.2).hit,"unpainted arc portion remains clear")
	check(model.physical.sweep(Vector2.ZERO,Vector2(6,0),.2).hit,"previewed portion blocks")
	var door_gesture=ConstructionGesture.new();door_gesture.raw_end=Vector2(-5,0)
	check(not editor.handlers[&"door"].propose_edit(context,door_gesture).valid,"same Door tool does not target missing arc")
	gesture.alternate=true
	var opposite=handler.propose_edit(context,gesture)
	check(opposite.valid and opposite.command.arc_width>quarter.command.arc_width*2,"Shift selects opposite sweep")
	model.execute(opposite.command)
	check(model.regions.locate(Vector2.ZERO).region_id>0,"complementary arc closes full room")
	# Input stages preserve one frozen snap step and never commit on first release.
	editor.select_tool(&"arc_wall")
	var before=model.structures.revision
	editor.begin_gesture(Vector2i(20,0),false,Vector2(20,0),1)
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
	editor._input(release)
	check(editor.dragging and model.structures.revision==before,"first release does not commit staged arc")
	editor.advance_control_point(Vector2i(25,0),Vector2(25,0))
	check(editor.dragging and editor.step_cells==1,"radius click preserves gesture")
	editor.advance_control_point(Vector2i(20,5),Vector2(20,5))
	check(not editor.dragging and model.structures.revision>before,"third click commits arc")
	editor.begin_gesture(Vector2i(30,0),false,Vector2(30,0),5)
	editor.advance_control_point(Vector2i(35,0),Vector2(35,0))
	editor.select_tool(&"square")
	check(not editor.dragging and editor.control_points.is_empty(),"tool switch clears staged points")
	editor.select_tool(&"arc_wall")
	editor.begin_gesture(Vector2i(20,0),false,Vector2(20,0),1)
	editor.advance_control_point(Vector2i(25,0),Vector2(25,0))
	var conflicting=InputEventMouseButton.new();conflicting.button_index=MOUSE_BUTTON_RIGHT;conflicting.pressed=true;conflicting.position=Vector2(600,400)
	Input.parse_input_event(conflicting);await process_frame
	check(not editor.dragging and not editor.camera.construction_active,"conflicting world press cancels without starting opposite gesture")
	conflicting.pressed=false;Input.parse_input_event(conflicting);await process_frame
	editor.begin_gesture(Vector2i.ZERO,false,Vector2.ZERO,1)
	editor._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not editor.dragging,"focus loss cancels arc")
	editor.begin_gesture(Vector2i.ZERO,false,Vector2.ZERO,1)
	var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;editor._input(escape)
	check(not editor.dragging and editor.control_points.is_empty(),"Escape cancels staged arc")
	editor.begin_gesture(Vector2i.ZERO,false,Vector2.ZERO,1)
	world.get_node("SpatialInspector").enter_inspect_mode()
	check(not editor.dragging and not editor.enabled,"inspection cancels staged arc")
	world.get_node("SpatialInspector").leave_inspect_mode()
	# Reproduce the supplied mixed floor's non-cardinal curve/straight join.
	model.floors.apply_polygon(editor.handlers[&"circle"].circle_polygon(Vector2i(50,0),Vector2i(55,0),1),false)
	model.floors.apply_rect(Rect2i(50,0,8,1),false)
	var join=Vector2.ZERO
	for loop in model.floors.boundary_loops():
		for p in loop:
			if p.y==1 and p.x>54 and p.x<55:join=p
	check(join!=Vector2.ZERO,"mixed floor has fractional circle intersection")
	gesture=ConstructionGesture.new();gesture.control_points=[Vector2i(50,0),Vector2i(55,0),Vector2i(55,1)]
	gesture.raw_end=join;gesture.start=Vector2i(50,0);gesture.end=Vector2i(55,1);gesture.alternate=true
	var partial=handler.propose_edit(context,gesture)
	check(partial.valid,"partial arc snaps to mixed floor boundary")
	var preview=partial.preview.paths[0]
	check(minf(preview[0].distance_to(join*context.cell_size),preview[-1].distance_to(join*context.cell_size))<.02,"arc endpoint meets actual floor intersection")
	model.execute(partial.command)
	var straight=ConstructionGesture.new();straight.start=Vector2i(58,1);straight.end=Vector2i(55,1);straight.raw_start=Vector2(58,1);straight.raw_end=join
	var wall=editor.handlers[&"wall"].propose_edit(context,straight)
	check(wall.valid and minf(Vector2(wall.command.a).distance_to(join),Vector2(wall.command.b).distance_to(join))<.0005,"straight wall tool snaps to fractional arc endpoint")
	model.execute(wall.command)
	model.execute(StructureCommand.wall(Vector2(55,0),Vector2(58,0),false))
	model.execute(StructureCommand.wall(Vector2(58,0),Vector2(58,1),false))
	check(model.regions.locate(Vector2(50,0)).region_id>0,"mixed floor outline can be enclosed without completing unwanted circle")
	check(model.physical.sweep(Vector2(54.9,.5),Vector2(55.5,.5),.01).hit==false,"unbuilt circular portion stays open inside mixed room")
	world.queue_free();await process_frame
	print("arc_tools: %d failures"%failures);quit(1 if failures else 0)
