extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world=load("res://world/world.tscn").instantiate();root.add_child(world)
	for i in range(5):await process_frame
	var editor=world.get_node("ConstructionPreview")
	check(editor.handlers.has(&"circular_wall"),"Circular Wall tool registered")
	if not editor.handlers.has(&"circular_wall"):
		world.queue_free();await process_frame;quit(1);return
	var model=world.get_node("WorldModel")
	editor.select_tool(&"circular_wall")
	editor.commit_stroke(Vector2i.ZERO,Vector2i(5,0),false)
	var region_id=model.regions.locate(Vector2.ZERO).region_id
	check(region_id>0,"circular wall encloses room")
	check(absf(model.regions.region(region_id).area-PI*25)<.2,"circular room area")
	check(model.regions.locate(Vector2(6,0)).region_id==0,"outside circle is exterior")
	check(model.structures.circle_points(model.structures.get_circles()[0])==editor.handlers[&"circle"].circle_polygon(Vector2i.ZERO,Vector2i(5,0),1),"Circular Wall matches Circle floor boundary exactly")
	world.get_node("SpatialInspector").overlay=true
	await process_frame
	await process_frame
	check(model.physical.sweep(Vector2.ZERO,Vector2(6,0),.2).hit,"circle blocks movement")
	var context=editor.construction_context()
	var gesture=ConstructionGesture.new();gesture.raw_end=Vector2(5,0)
	var door=editor.handlers[&"door"]
	var proposal=door.propose_edit(context,gesture)
	check(proposal.valid,"same door tool fits circle seam")
	if proposal.valid:
		check(model.execute(proposal.command).accepted,"curved door commits")
		var d=model.structures.get_doors()[0]
		check(d.has("path") and d.path.size()>2,"door follows curvature across sampled segments")
		check(model.regions.locate(Vector2.ZERO).region_id==region_id,"door preserves room identity")
		check(model.physical.sweep(Vector2(4,0),Vector2(6,0),.2).hit,"closed curved door blocks")
		model.execute(StructureCommand.door_action(d.id,&"OPEN"))
		check(not model.physical.sweep(Vector2(4,0),Vector2(6,0),.2).hit,"open curved door clears whole aperture")
		check(model.physical.visibility_hits(Vector2(4,0),Vector2(6,0)).is_empty(),"open curved door clears sight")
		check(model.physical.crossing_option(d.id,{"radius":.2}).kind==&"PASS","body fits curved opening")
		check(model.physical.crossing_option(d.id,{"radius":.5}).kind==&"BLOCKED","wide body cannot fit curved opening")
		check(StructureCodec.decode(StructureCodec.encode(model.structures)).valid,"circular structures roundtrip")
	gesture.raw_end=Vector2(-3.5355,-3.5355);gesture.step=25;context.camera_scale=.1
	proposal=door.propose_edit(context,gesture)
	check(proposal.valid and absf(CircleBoundary.length(proposal.preview.paths[0])/context.cell_size-1)<.00001,"same door tool previews curved one-cell aperture at coarse zoom")
	var stale_command=proposal.command
	editor.select_tool(&"circular_wall");editor.commit_stroke(Vector2i.ZERO,Vector2i(5,0),true)
	check(model.structures.get_circles().is_empty() and model.structures.get_doors().is_empty(),"Circular Wall erasure removes loop and attached doors")
	check(not model.execute(stale_command).accepted,"stale curved door refuses deleted host")
	check(not model.floors.contains_point(Vector2.ZERO),"circular wall tool does not paint floors")
	world.queue_free();await process_frame
	print("circular_walls: %d failures"%failures);quit(1 if failures else 0)
