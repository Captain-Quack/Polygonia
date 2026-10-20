extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://world/world.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var gore = scene.get_node_or_null("GoreRenderer")
	check(gore != null,"world includes a dedicated ground-effects layer")
	if gore != null:
		check(gore.get_index() > scene.get_node("FloorRenderer").get_index() and gore.get_index() < scene.get_node("WallRenderer").get_index(),"blood draws above floors and below walls")
	check(scene.get_node("ConstructionPreview").z_index > scene.get_node("SurvivalView").z_index,"construction overlays remain above gore and agents")
	check(scene.get_node("SpatialInspector").z_index > scene.get_node("SurvivalView").z_index,"inspection overlays remain above effects")
	scene.queue_free(); await process_frame
	print("gore_layers: %d failures" % failures); quit(1 if failures else 0)
