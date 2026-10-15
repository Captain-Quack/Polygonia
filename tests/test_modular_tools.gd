extends SceneTree
var failures := 0
var selections: Array[StringName] = []
class TestHandler extends ConstructionToolHandler:
	var commits := 0
	func _init() -> void:
		tool_id = &"third"
	func commit(data, a: Vector2i, _b: Vector2i, step: int, erase: bool) -> void:
		commits += 1
		data.apply_rect(Rect2i(a, Vector2i.ONE * step), erase)
	func preview_geometry(a: Vector2i, _b: Vector2i, _step: int, cell: float, _radius: float) -> Dictionary:
		return {"paths": [PackedVector2Array([Vector2(a) * cell, Vector2(a + Vector2i.ONE) * cell])], "fills": [], "closed": false}
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(5):
		await process_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var registered: Array = ProjectSettings.get_global_class_list().map(func(item): return item["class"])
	check("ConstructionToolDefinition" in registered and "ConstructionCategoryDefinition" in registered, "Resource classes registered for Inspector creation")
	var world = load("res://world/world.tscn").instantiate()
	root.size = Vector2i(1280, 800)
	root.add_child(world)
	await settle()
	var editor = world.get_node("ConstructionPreview")
	var menu = editor.menu
	check(menu.categories.size() == 2, "Default category is visible as an Inspector resource in scene")
	var extra := ConstructionCategoryDefinition.new()
	extra.category_id = &"extra"
	extra.title = "Extra tools"
	var third := ConstructionToolDefinition.new()
	third.tool_id = &"third"
	third.display_name = "Third tool"
	third.tooltip = "Custom behavior"
	extra.tools = [third]
	menu.categories.append(extra)
	await settle()
	check(menu.buttons.size() == 7 and menu.category_buttons.size() == 3, "Third tool and second category appear without menu edits")
	check(menu.buttons[&"third"].disabled and "No construction handler" in menu.buttons[&"third"].tooltip_text, "Unsupported tool disabled with explanation")
	check(menu.buttons[&"third"].text == "Third tool", "Missing icon falls back to label")
	var handler := TestHandler.new()
	check(editor.register_handler(handler), "Custom handler registers")
	check(not menu.buttons[&"third"].disabled, "Registration enables the button")
	menu.tool_selected.connect(func(id: StringName): selections.append(id))
	for i in range(5):
		menu.rebuild()
	await settle()
	menu.buttons[&"third"].pressed.emit()
	check(selections == [&"third"] and editor.tool == &"third", "Repeated rebuilds retain one selection callback")
	check(menu.buttons[&"third"].button_pressed and not menu.buttons[&"line"].button_pressed, "Selection exclusive across categories")
	editor.commit_stroke(Vector2i(9, 9), Vector2i(10, 10), false)
	check(handler.commits == 1 and editor.data.contains(Vector2i(9, 9)), "Custom behavior commits through registry")
	editor.dragging = true
	editor.camera.construction_active = true
	editor.start = Vector2i.ONE
	editor.endpoint = Vector2i(2, 2)
	await settle()
	menu.select_tool(&"square")
	check(not editor.dragging and not editor.camera.construction_active, "Tool selection cancels stroke and unlocks camera")
	third.display_name = "Renamed"
	third.tooltip = "Updated hint"
	await settle()
	check(menu.buttons[&"third"].text == "Renamed" and menu.buttons[&"third"].tooltip_text == "Updated hint", "Live resource edits refresh presentation")
	menu.select_tool(&"third")
	var bottom: float = menu.get_global_rect().end.y
	for i in range(10):
		menu.set_category_expanded(&"extra", false)
		menu.set_category_expanded(&"shapes", false)
		await settle()
		check(menu.selected_tool == &"third" and is_equal_approx(menu.get_global_rect().end.y, bottom), "Collapse preserves selection and bottom")
		menu.set_category_expanded(&"extra", true)
		menu.set_category_expanded(&"shapes", true)
		await settle()
		check(is_equal_approx(menu.get_global_rect().end.y, bottom), "Reopen preserves bottom")
	menu.columns = 1
	menu.button_size = 72
	root.size = Vector2i(1024, 600)
	await settle()
	check(menu.tool_grids[&"shapes"].columns == 1 and is_equal_approx(menu.get_global_rect().end.y, 582.0), "Wrapping and viewport resizing preserve bottom margin")
	# Invalid entries do not prevent valid entries from working.
	var invalid := ConstructionToolDefinition.new()
	extra.tools.append(invalid)
	extra.tools.append(third)
	menu.categories.append(extra)
	await settle()
	check(menu.buttons.size() == 7 and menu.configuration_warnings.size() == 3, "Empty and duplicate IDs are skipped with warnings")
	check(menu.buttons.keys() == [&"line", &"square", &"circle", &"wall", &"circular_wall", &"door", &"third"], "Definitions preserve tool ordering")
	# Remove selected definition while dragging: fallback must cancel the stroke.
	editor.dragging = true
	editor.camera.construction_active = true
	extra.tools.clear()
	await settle()
	check(editor.tool == &"line" and not editor.dragging, "Removing selected definition selects fallback and cancels")
	editor.unregister_handler(&"line")
	editor.unregister_handler(&"square")
	editor.unregister_handler(&"circle")
	editor.unregister_handler(&"wall")
	editor.unregister_handler(&"circular_wall")
	editor.unregister_handler(&"door")
	check(editor.tool == &"", "No supported menu tools deactivates construction")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	editor._unhandled_input(press)
	check(not editor.dragging, "Inactive construction ignores drawing input")
	menu.categories.clear()
	await settle()
	var fallback = load("res://floors/tools/default_category.tres")
	fallback.tools.append(third)
	await settle()
	check(menu.buttons.has(&"third"), "Legacy fallback category array edits refresh")
	fallback.tools.erase(third)
	world.queue_free()
	await settle()
	print("Modular tool tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
