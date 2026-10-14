extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://world/world.tscn")
	if scene == null:
		check(false, "World scene must exist")
		quit(1)
		return
	var world = scene.instantiate()
	root.add_child(world)
	await process_frame
	var grid = world.get_node("GridRenderer")
	check(grid.world_to_cell(Vector2(-1, -65)) == Vector2i(-1, -2), "Negative cell mapping floors")
	check(grid.cell_to_world(Vector2i(2, -3)) == Vector2(128, -192), "Cells use fixed base units")
	grid.major_step_count = 7
	grid.level_step_count = 3
	await process_frame
	check(grid.material.get_shader_parameter("major_step_count") == 7, "Major step independent")
	check(grid.material.get_shader_parameter("level_step_count") == 3, "Level step independent")
	var camera = world.get_node("Camera2D")
	var button = world.get_node("CanvasLayer/WorldControls/ResetView")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = button.get_global_rect().get_center()
	wheel.factor = 1.0
	root.push_input(wheel)
	check(is_equal_approx(camera._target_zoom, 1.0), "Wheel over UI does not zoom")
	camera.reset_view()
	camera.zoom_smoothing = 0.0
	camera.position = Vector2(120, -60)
	camera.force_update_scroll()
	var cursor := Vector2(201, 177)
	var before: Vector2 = root.get_canvas_transform().affine_inverse() * cursor
	camera.zoom_about(cursor, 2.0)
	camera.force_update_scroll()
	var after: Vector2 = root.get_canvas_transform().affine_inverse() * cursor
	check(before.distance_to(after) < 0.001, "Cursor remains anchored")
	camera.zoom_about(cursor, 100000.0)
	check(is_equal_approx(camera.zoom.x, camera.maximum_zoom), "Zoom capped")
	camera.reset_view()
	check(camera.position == camera.home_position, "Reset position")
	check(is_equal_approx(camera.zoom.x, camera.initial_zoom), "Reset zoom")
	camera.minimum_zoom = 4.0
	camera.maximum_zoom = 0.5
	camera.zoom_about(cursor, 0.01)
	check(is_equal_approx(camera.zoom.x, 0.5), "Reversed limits normalized")
	print("Polygonia tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
