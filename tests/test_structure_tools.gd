extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world=load("res://world/world.tscn").instantiate();root.add_child(world)
	for i in range(5):await process_frame
	var editor=world.get_node("ConstructionPreview")
	check(editor.handlers.has(&"wall") and editor.handlers.has(&"door"),"Structure tools registered through resources")
	if editor.handlers.has(&"wall") and editor.handlers.has(&"door"):
		var model=world.get_node("WorldModel")
		editor.select_tool(&"wall");editor.commit_stroke(Vector2i(8,0),Vector2i.ZERO,false)
		check(model.structures.get_walls().size()==1,"wall tool commits")
		var context=editor.construction_context()
		var gesture=ConstructionGesture.new();gesture.raw_end=Vector2(1.5,0);gesture.end=Vector2i(2,0)
		var handler=editor.handlers[&"door"]
		var proposal=handler.propose_edit(context,gesture)
		check(proposal.valid,"door on host valid")
		model.execute(proposal.command)
		check(model.structures.get_doors()[0].b-model.structures.get_doors()[0].a==Vector2i(1,0),"door fixed physical width")
		gesture.raw_end=Vector2(5.5,0);context.camera_scale=.1;gesture.step=25
		proposal=handler.propose_edit(context,gesture)
		check(proposal.valid and proposal.command.b-proposal.command.a==Vector2i(1,0),"coarse zoom retains door width")
		model.execute(StructureCommand.wall(Vector2i(4,0),Vector2i(8,0),true))
		check(not model.execute(proposal.command).accepted,"stale door proposal revalidated")
		gesture.raw_end=Vector2(20,20)
		check(not handler.propose_edit(context,gesture).valid,"invalid host no relocation")
		editor.dragging=true;editor.select_tool(&"square")
		check(not editor.dragging,"tool change cancels")
	check(world.has_node("SpatialInspector"),"Spatial inspector exists")
	if world.has_node("SpatialInspector"):
		var inspector=world.get_node("SpatialInspector")
		inspector.enter_inspect_mode()
		check(not editor.enabled,"Inspect mode disables painting")
		inspector.select_at(Vector2(-10,-10))
		check(inspector.selected_region_id==0 and "Unknown" in inspector.description.text,"Exterior inspection has unknown coverage")
		inspector.leave_inspect_mode()
		check(editor.enabled,"Construction mode restores painting")
	world.queue_free();await process_frame
	print("structure_tools: %d failures"%failures);quit(1 if failures else 0)
