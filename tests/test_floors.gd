extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var data = load("res://floors/floor_data.gd").new()
	data.apply_rect(Rect2i(-5, -5, 10, 10), false)
	data.apply_rect(Rect2i(-2, -2, 4, 4), true)
	check(not data.contains(Vector2i.ZERO), "Erase removes interior")
	check(data.contains(Vector2i(-5, -5)), "Erase preserves outside")
	data.apply_rect(Rect2i(-1, -1, 2, 2), false)
	check(data.contains(Vector2i.ZERO), "Repaint fills erased area")
	for a in range(data.regions.size()):
		for b in range(a + 1, data.regions.size()):
			check(not data.regions[a].intersects(data.regions[b]), "Regions never overlap")
	data.apply_rect(Rect2i(-100000, -100000, 200000, 200000), false)
	check(data.regions.size() == 1, "Large fill is compact")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var editor = world.get_node("ConstructionPreview")
	check(editor.handlers[&"square"].shape(Vector2i(4, 3), Vector2i(1, -1), 1) == Rect2i(1, -1, 3, 4), "Rectangle reverse drag")
	check(editor.handlers[&"line"].line_endpoint(Vector2i.ZERO, Vector2i(5, 2)) == Vector2i(5, 0), "Line locks dominant axis")
	check(editor.visible_step() == 1, "Base snap at normal zoom")
	world.get_node("Camera2D").zoom = Vector2.ONE * 0.05
	check(editor.visible_step() == 5, "Snap follows dominant coarse grid")
	editor.select_tool(&"square")
	check(editor.menu.buttons[&"square"].button_pressed and not editor.menu.buttons[&"line"].button_pressed, "Exclusive tools")
	editor.dragging = true
	editor.erasing = false
	var second := InputEventMouseButton.new()
	second.button_index = MOUSE_BUTTON_RIGHT
	second.pressed = true
	editor._unhandled_input(second)
	check(not editor.erasing, "Second button cannot replace active stroke")
	editor.cancel()
	check(not world.get_node("Camera2D").construction_active, "Cancel releases camera")
	print("Floor tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
