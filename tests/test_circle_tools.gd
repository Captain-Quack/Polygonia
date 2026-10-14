extends SceneTree
const Data = preload("res://floors/floor_data.gd")
const Geometry = preload("res://floors/shape_geometry.gd")
const Circle = preload("res://floors/tools/circle_handler.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func area(polygon: PackedVector2Array) -> float:
	var value := 0.0
	for i in range(polygon.size()):
		value += (polygon[i] - polygon[0]).cross(polygon[(i + 1) % polygon.size()] - polygon[0])
	return absf(value) * 0.5
func bands_area(data) -> float:
	var total := 0.0
	for band in Geometry.fill_bands(data.boundary_loops()):
		total += area(band)
		check(not Geometry2D.triangulate_polygon(band).is_empty(), "Shared floor produces drawable fill bands")
	return total
func contour_contains(data, point: Vector2) -> bool:
	var inside := false
	for loop in data.boundary_loops():
		if Geometry2D.is_point_in_polygon(point, loop):
			inside = not inside
	return inside
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var circle := Circle.new()
	check(circle.snapped_radius(Vector2i(10, 8), Vector2i(13, 8), 1) == 3, "Cardinal drag radius snaps exactly")
	check(circle.snapped_radius(Vector2i.ZERO, Vector2i(3, 3), 1) == 4, "Diagonal distance quantizes radius")
	check(circle.snapped_radius(Vector2i(-10, -10), Vector2i(-5, -5), 5) == 5, "Coarse grid and negative center snap")
	var polygon: PackedVector2Array = circle.circle_polygon(Vector2i.ZERO, Vector2i(4, 0), 1)
	check(polygon.size() >= 64 and polygon.size() % 4 == 0, "Circle sample count preserves cardinals")
	check(polygon[0] == Vector2(4, 0) and polygon[polygon.size()/4] == Vector2(0, 4), "Cardinal extents sit exactly on grid")
	check(absf(area(polygon) - PI * 16) < 0.1, "Circle approximation preserves area")
	var preview: Dictionary = circle.preview_geometry(Vector2i.ZERO, Vector2i(4, 0), 1, 64, 10)
	for i in range(polygon.size()):
		check(preview.paths[0][i] == polygon[i] * 64, "Preview uses committed geometry")
	check(preview.guides.size() == 1 and preview.markers.size() == 5 and "4" in preview.label, "Preview explains snapped radius and extents")
	check(circle.circle_polygon(Vector2i.ZERO, Vector2i.ZERO, 1).is_empty(), "Click without drag creates no circle")
	check(Geometry.rounded_loop(polygon, 0.2) == polygon, "Circle vertices stay on original circumference")
	var data := Data.new()
	circle.commit(data, Vector2i.ZERO, Vector2i(4, 0), 1, false)
	check(data.boundary_loops().size() == 1, "Circle has one exterior")
	check(absf(bands_area(data) - area(polygon)) < 0.01, "Circle contour and fill area agree")
	data.apply_line(Vector2i(-8, 0), Vector2i(8, 0), false)
	data.apply_rect(Rect2i(-1, -1, 2, 2), true)
	check(not data.contains_point(Vector2.ZERO) and data.contains_point(Vector2(2, 0)), "Square erases a hole in circular floor")
	check(data.boundary_loops().size() == 2, "Square hole has its own contour")
	check(absf(bands_area(data) - area(polygon) + 4) < 0.01, "Hole is absent from translucent fill")
	data.apply_rect(Rect2i(-1, -1, 2, 2), false)
	check(data.boundary_loops().size() == 1, "Repainting hole removes internal seam")
	check(absf(bands_area(data) - area(polygon)) < 0.01, "Repaint restores area without double fill")
	var count: int = data.polygon_floor.pieces.size()
	for i in range(5):
		circle.commit(data, Vector2i.ZERO, Vector2i(4, 0), 1, false)
	check(data.polygon_floor.pieces.size() == count, "Repeated paint does not fragment identical geometry")
	check(data.lines.size() == 1, "Floor edits preserve Line strokes")
	var nested := Data.new()
	nested.apply_rect(Rect2i(-6, -6, 12, 12), false)
	circle.commit(nested, Vector2i.ZERO, Vector2i(4, 0), 1, true)
	circle.commit(nested, Vector2i.ZERO, Vector2i(2, 0), 1, false)
	circle.commit(nested, Vector2i.ZERO, Vector2i(1, 0), 1, true)
	check(nested.boundary_loops().size() == 4, "Nested hole, island and hole preserve all boundaries")
	check(not nested.contains_point(Vector2.ZERO) and nested.contains_point(Vector2(1.5, 0)) and not nested.contains_point(Vector2(3, 0)), "Nested occupancy correct")
	check(absf(bands_area(nested) - (144 - area(polygon) + area(circle.circle_polygon(Vector2i.ZERO, Vector2i(2,0),1)) - area(circle.circle_polygon(Vector2i.ZERO,Vector2i(1,0),1)))) < 0.02, "Nested holes fill exactly once")
	var touching := Data.new()
	circle.commit(touching, Vector2i.ZERO, Vector2i(2, 0), 1, false)
	touching.apply_rect(Rect2i(2, -1, 2, 2), false)
	check(touching.boundary_loops().size() == 2, "Point tangent circle and square retain separate exteriors")
	touching.apply_rect(Rect2i(1, -1, 2, 2), false)
	check(touching.boundary_loops().size() == 1, "Actual overlap merges exteriors")
	var before: float = bands_area(touching)
	check(not touching.apply_polygon(PackedVector2Array(), false), "Empty polygon rejected")
	check(not touching.apply_polygon(PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2(2,2)]), true), "Zero-area polygon rejected")
	check(is_equal_approx(bands_area(touching), before), "Invalid edit preserves floor")
	check(not touching.apply_polygon(PackedVector2Array([Vector2(0,0),Vector2(4,0),Vector2(4,4),Vector2(0,4),Vector2(4,0)]),false), "Repeated nonadjacent vertex rejects invalid polygon")
	for position in [Vector2i(100000,100000),Vector2i(300000,300000)]:
		var distant := Data.new()
		circle.commit(distant, position, position + Vector2i(4,0), 1, false)
		check(distant.contains_point(Vector2(position)) and distant.boundary_loops().size() == 1, "Distant circle remains valid away from origin")
	var concave := Data.new()
	var l_shape := PackedVector2Array([Vector2(0,0),Vector2(3,0),Vector2(3,1),Vector2(1,1),Vector2(1,3),Vector2(0,3)])
	check(concave.apply_polygon(l_shape,false), "Simple concave polygon accepted")
	check(absf(bands_area(concave)-5.0) < 0.01 and not concave.contains_point(Vector2(2,2)), "Concave input preserves its recess")
	l_shape.reverse()
	check(concave.apply_polygon(l_shape,false) and absf(bands_area(concave)-5.0) < 0.01, "Reversed polygon winding preserves paint semantics")
	# Deterministic mixed edits compared against an independent point oracle.
	var mixed := Data.new()
	var edits: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 80371
	for index in range(24):
		var a := Vector2i(rng.randi_range(-6,6), rng.randi_range(-6,6))
		var radius := rng.randi_range(1,4)
		var erase := index % 3 == 0
		var shape: PackedVector2Array
		if index % 2 == 0:
			shape = circle.circle_polygon(a, a + Vector2i(radius,0), 1)
			circle.commit(mixed, a, a + Vector2i(radius,0), 1, erase)
		else:
			var rect := Rect2i(a, Vector2i(radius + 1, radius + 2))
			shape = load("res://floors/polygon_floor.gd").rect_polygon(rect)
			mixed.apply_rect(rect, erase)
		edits.append([shape, erase])
		for x in range(-8,9):
			for y in range(-8,9):
				var point := Vector2(x + 0.371, y + 0.283)
				var expected := false
				for edit in edits:
					if Geometry2D.is_point_in_polygon(point, edit[0]):
						expected = not edit[1]
				check(mixed.contains_point(point) == expected, "Mixed circle/rectangle point occupancy matches oracle")
				check(contour_contains(mixed, point) == expected, "Shared outlines match mixed-edit occupancy")
		var piece_area := 0.0
		for piece in mixed.polygon_floor.pieces:
			piece_area += area(piece)
		check(absf(bands_area(mixed) - piece_area) < 0.05, "Contours preserve all non-overlapping piece area")
	var overlap_grid := Data.new()
	for index in range(25):
		var center := Vector2i((index % 5) * 3, (index / 5) * 3)
		circle.commit(overlap_grid, center, center + Vector2i(5,0), 1, false)
	check(overlap_grid.boundary_loops().size() == 1, "Twenty-five overlapping circles merge into one outline")
	check(overlap_grid.polygon_floor.pieces.size() < 256, "Repeated overlaps compact convex storage")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	for i in range(4):
		await process_frame
	var editor = world.get_node("ConstructionPreview")
	check(editor.menu.buttons.has(&"circle") and not editor.menu.buttons[&"circle"].disabled, "Circle is registered in world through resources")
	editor.select_tool(&"circle")
	editor.step_cells = 5
	editor.commit_stroke(Vector2i(-10,-10),Vector2i(-5,-10),false)
	var rendered: Array = []
	for loop in editor.data.boundary_loops():
		var points := PackedVector2Array()
		for point in loop:
			points.append(Vector2(point) * 64)
		rendered.append(Geometry.rounded_loop(points, 10))
	for band in Geometry.fill_bands(rendered):
		var local := band.duplicate()
		for i in range(local.size()):
			local[i] -= band[0]
		check(not Geometry2D.triangulate_polygon(local).is_empty(), "Committed coarse circle renders valid local polygons")
	check(editor.data.contains_point(Vector2(-10,-10)) and not editor.data.contains_point(Vector2(-4,-10)), "Integrated Circle commits coarse snapped floor")
	editor.dragging = true
	editor.start = Vector2i(-10,-10)
	editor.endpoint = Vector2i(-5,-10)
	for zoom in [0.05, 1.0, 8.0]:
		editor.camera.zoom = Vector2.ONE * zoom
		editor.camera._target_zoom = zoom
		await process_frame
		await process_frame
	editor.select_tool(&"square")
	check(not editor.dragging, "Switching away cancels circle preview")
	world.queue_free()
	await process_frame
	print("Circle tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
