extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	var model=load("res://world/world_model.gd").new()
	var change=model.execute(StructureCommand.wall(Vector2i(2,3),Vector2i(7,3),false))
	check(change.affected_bounds.has_point(Vector2(4,3)),"Events locate changed structures")
	change=model.execute(StructureCommand.place_door(Vector2i(4,3),Vector2i(5,3)))
	check(change.entity_id>0 and not change.new_state.is_empty(),"Placement identifies new door")
	var id=model.structures.get_doors()[0].id
	var topology=model.structures.topology_revision
	var open=model.execute(StructureCommand.door_action(id,&"OPEN",42))
	check(open.actor_id==42,"event actor")
	StructureCommand.restore(model,open,true)
	check(model.structures.topology_revision==topology,"undoing state does not change topology")
	check(model.has_method("replace_structures"),"World supports validated replacement")
	if model.has_method("replace_structures"):
		var payload=StructureCodec.encode(model.structures)
		var before=model.structures.revision
		check(not model.replace_structures({"version":99}).accepted and model.structures.revision==before,"invalid load atomic")
		check(model.replace_structures(payload).accepted,"valid replacement")
	var stale=StructureCommand.restore(model,open,true)
	check(not stale.accepted and stale.revision==model.structures.revision and stale.previous_revision==stale.revision,"stale restore preserves revision")
	var opened=model.execute(StructureCommand.door_action(id,&"OPEN"))
	model.occupancy_query=func(_capsule):return true
	var occupied=StructureCommand.restore(model,opened,true)
	check(not occupied.accepted and occupied.revision==model.structures.revision and occupied.previous_revision==occupied.revision,"occupied restore preserves revision")
	model.free()
	print("structure_events: %d failures"%failures);quit(1 if failures else 0)
