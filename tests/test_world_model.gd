extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	for i in range(5): await process_frame
	var editor = world.get_node("ConstructionPreview")
	check(world.has_node("WorldModel"), "World owns shared model")
	if world.has_node("WorldModel"):
		var model = world.get_node("WorldModel")
		check(editor.data == model.floors, "Editor compatibility accessor shares floor identity")
		check(world.get_node("FloorRenderer").data == model.floors, "Renderer shares floor identity")
	world.queue_free()
	await process_frame
	print("world_model: %d failures" % failures)
	quit(1 if failures else 0)
