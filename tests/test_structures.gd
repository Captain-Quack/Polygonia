extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	if not ResourceLoader.exists("res://structures/structure_command.gd"):
		check(false, "Structure commands exist")
		quit(1)
		return
	var C = load("res://structures/structure_command.gd")
	var model = load("res://world/world_model.gd").new()
	check(model.execute(C.wall(Vector2i(8,0),Vector2i.ZERO,false)).accepted, "reversed wall")
	model.execute(C.wall(Vector2i(4,0),Vector2i(10,0),false))
	check(model.structures.get_walls().size()==1, "overlap union")
	var d = model.execute(C.place_door(Vector2i(2,0),Vector2i(4,0)))
	check(d.accepted, "supported aperture")
	var id = model.structures.get_doors()[0].id
	var revision = model.structures.revision
	check(not model.execute(C.wall(Vector2i(2,0),Vector2i(3,0),true)).accepted, "partial aperture erase rejected")
	check(model.structures.revision==revision, "rejection atomic")
	check(not model.execute(C.wall(Vector2i(3,-2),Vector2i(3,2),false)).accepted, "crossing aperture rejected")
	check(not model.execute(C.place_door(Vector2i(4,0),Vector2i(5,0))).accepted, "adjacent door rejected")
	model.execute(C.wall(Vector2i(-2,0),Vector2i(10,0),false))
	check(model.structures.get_doors()[0].id==id, "door identity survives wall normalization")
	model.execute(C.remove_door(id))
	check(model.structures.get_doors().is_empty() and model.structures.get_walls().size()==1, "door removal restores wall")
	model.execute(C.wall(Vector2i(3,0),Vector2i(7,0),true))
	check(model.structures.get_walls().size()==2, "wall subtraction")
	var Codec = load("res://structures/structure_codec.gd")
	var encoded = Codec.encode(model.structures)
	check(Codec.decode(encoded).valid, "codec roundtrip")
	var bad = encoded.duplicate(true)
	bad.version = 99
	check(not Codec.decode(bad).valid, "future schema rejected")
	bad = encoded.duplicate(true)
	bad.walls[1].id = bad.walls[0].id
	check(not Codec.decode(bad).valid, "duplicate ids rejected")
	var change = model.execute(C.place_door(Vector2i(-1,0),Vector2i(0,0)))
	check(change.accepted, "place before restore")
	check(C.restore(model,change,true).accepted and model.structures.get_doors().is_empty(), "undo")
	check(C.restore(model,change,false).accepted and model.structures.get_doors().size()==1, "redo")
	model.free()
	print("structures: %d failures" % failures)
	quit(1 if failures else 0)
