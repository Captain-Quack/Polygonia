extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for i in range(4):
		await process_frame
func run() -> void:
	root.size = Vector2i(1280, 800)
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await settle()
	var menu = world.get_node("CanvasLayer/ConstructionMenu")
	var bottom: float = menu.category_buttons[&"shapes"].get_global_rect().end.y
	print("Initial bottom: ", bottom, " offsets ", menu.offset_top, " ", menu.offset_bottom)
	for i in range(20):
		menu.category_buttons[&"shapes"].button_pressed = false
		await settle()
		var collapsed_bottom: float = menu.category_buttons[&"shapes"].get_global_rect().end.y
		menu.category_buttons[&"shapes"].button_pressed = true
		await settle()
		var expanded_bottom: float = menu.category_buttons[&"shapes"].get_global_rect().end.y
		print("Cycle ", i, ": collapsed ", collapsed_bottom, " expanded ", expanded_bottom, " offsets ", menu.offset_top, " ", menu.offset_bottom)
		if absf(collapsed_bottom - bottom) > 0.1 or absf(expanded_bottom - bottom) > 0.1:
			failures += 1
	var margin: float = root.size.y - menu.category_buttons[&"shapes"].get_global_rect().end.y
	root.size = Vector2i(1024, 600)
	await settle()
	if absf(root.size.y - menu.category_buttons[&"shapes"].get_global_rect().end.y - margin) > 0.1:
		failures += 1
	print("Menu layout tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
