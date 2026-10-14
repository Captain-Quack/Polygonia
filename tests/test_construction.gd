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
	check(data.has_method("apply_line"), "Line strokes must be stored separately from floor rectangles")
	check(data.has_method("boundary_loops"), "Connected floors need exterior boundaries without internal seams")
	if not data.has_method("apply_line") or not data.has_method("boundary_loops"):
		quit(1)
		return
	data.apply_line(Vector2i(5, 0), Vector2i(-5, 0), false)
	check(data.regions.is_empty(), "Drawing a line does not fill floor cells")
	data.apply_line(Vector2i(3, 0), Vector2i(8, 0), false)
	check(data.lines.size() == 1 and data.lines[0] == Vector4i(-5, 0, 8, 0), "Collinear overlapping lines merge, including reverse drags")
	data.apply_line(Vector2i(-2, 0), Vector2i(2, 0), true)
	check(data.lines.size() == 2, "Erasing an interior section splits the line")
	data.apply_line(Vector2i(0, -5), Vector2i(0, 5), false)
	data.apply_line(Vector2i(0, -1), Vector2i(0, 1), true)
	check(data.lines.size() == 4, "Vertical strokes split without deleting nearby horizontal strokes")
	data.apply_rect(Rect2i(0, 0, 3, 3), false)
	data.apply_rect(Rect2i(3, 0, 2, 3), false)
	var loops: Array = data.boundary_loops()
	check(loops.size() == 1, "Adjacent floor rectangles share a single contour")
	var perimeter := 0.0
	for loop in loops:
		for i in range(loop.size()):
			perimeter += Vector2(loop[i]).distance_to(Vector2(loop[(i+1)%loop.size()]))
	check(is_equal_approx(perimeter, 16.0), "Only exterior edges are outlined")
	data.apply_rect(Rect2i(1, 1, 1, 1), true)
	check(data.boundary_loops().size() == 2, "An erased interior has its own hole boundary")
	var touching = load("res://floors/floor_data.gd").new()
	touching.apply_rect(Rect2i(0, 0, 2, 2), false)
	touching.apply_rect(Rect2i(2, 2, 2, 2), false)
	check(touching.boundary_loops().size() == 2, "Corner-touching floors keep valid separate contours")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var editor = world.get_node("ConstructionPreview")
	check(editor.handlers[&"line"].has_method("line_endpoint"), "Line input produces snapped endpoints rather than boxes")
	if editor.handlers[&"line"].has_method("line_endpoint"):
		check(editor.handlers[&"line"].line_endpoint(Vector2i(1, 1), Vector2i(6, 3)) == Vector2i(6, 1), "Line locks to horizontal grid edge")
		check(editor.handlers[&"line"].line_endpoint(Vector2i(1, 1), Vector2i(-1, -8)) == Vector2i(1, -8), "Line locks to vertical grid edge")
	var menu = world.get_node_or_null("CanvasLayer/ConstructionMenu")
	check(menu != null, "World has a collapsible construction category")
	if menu != null:
		editor.select_tool(&"square")
		menu.set_category_expanded(&"shapes", false)
		await process_frame
		check(not menu.tool_grids[&"shapes"].visible and editor.tool == &"square", "Collapsing menu preserves selected tool")
		menu.set_category_expanded(&"shapes", true)
		await process_frame
		check(menu.tool_grids[&"shapes"].visible, "Category reopens tools")
		check(menu.buttons[&"square"].definition.icon != null, "Square gets a distinct filled-square icon")
		var camera = world.get_node("Camera2D")
		var old_zoom: float = camera._target_zoom
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = menu.category_buttons[&"shapes"].get_global_rect().get_center()
		root.push_input(wheel)
		check(is_equal_approx(camera._target_zoom, old_zoom), "Category consumes wheel events")
	editor.select_tool(&"line")
	editor.commit_stroke(Vector2i(-3, 0), Vector2i(4, 1), false)
	check(editor.data.regions.is_empty(), "Actual line commit creates no floor area")
	check(editor.data.lines == [Vector4i(-3, 0, 4, 0)], "Actual line commit stores grid-aligned segment")
	editor.commit_stroke(Vector2i(4, 0), Vector2i(5, 4), false)
	editor.select_tool(&"square")
	editor.commit_stroke(Vector2i(-2, -2), Vector2i(2, 2), false)
	editor.commit_stroke(Vector2i(2, -1), Vector2i(4, 2), false)
	editor.commit_stroke(Vector2i(-1, -1), Vector2i(1, 1), true)
	check(editor.data.contains(Vector2i(-2, -2)) and not editor.data.contains(Vector2i.ZERO), "Square commits and erases filled areas")
	check(editor.data.lines.size() == 2, "Square erasing leaves line boundaries intact")
	for zoom_value in [0.002, 0.05, 1.0, 8.0]:
		world.get_node("Camera2D").zoom = Vector2.ONE * zoom_value
		world.get_node("Camera2D")._target_zoom = zoom_value
		await process_frame
		await process_frame
	print("Construction tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
