extends SceneTree
const Geometry = preload("res://floors/shape_geometry.gd")
const Data = preload("res://floors/floor_data.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func area(points: PackedVector2Array) -> float:
	var value := 0.0
	for i in range(points.size()):
		value += points[i].cross(points[(i+1)%points.size()])
	return absf(value) * 0.5
func run_geometry(data: RefCounted, expected_area: float) -> void:
	var loops: Array = []
	for loop in data.boundary_loops():
		var points := PackedVector2Array()
		for p in loop:
			points.append(Vector2(p))
		loops.append(points)
	var bands := Geometry.fill_bands(loops)
	var total := 0.0
	for band in bands:
		total += area(band)
	check(is_equal_approx(total, expected_area), "Union contours preserve occupied area, including holes and corner touches")
func _initialize() -> void:
	var data := Data.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 36217
	var occupied := {}
	for index in range(120):
		var rect := Rect2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8), rng.randi_range(1, 6), rng.randi_range(1, 6))
		var erase := index % 3 == 0
		data.apply_rect(rect, erase)
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				if erase:
					occupied.erase(Vector2i(x,y))
				else:
					occupied[Vector2i(x,y)] = true
		run_geometry(data, occupied.size())
	var outer := PackedVector2Array([Vector2(0,0),Vector2(100,0),Vector2(100,100),Vector2(0,100)])
	var hole := PackedVector2Array([Vector2(25,25),Vector2(25,75),Vector2(75,75),Vector2(75,25)])
	var loops := [Geometry.rounded_loop(outer, 10), Geometry.rounded_loop(hole, 10)]
	for band in Geometry.fill_bands(loops):
		check(not Geometry2D.is_point_in_polygon(Vector2(50,50), band), "Rounded floor keeps erased hole empty")
		if Geometry2D.triangulate_polygon(band).is_empty():
			print("Invalid band: ", band, " area ", area(band))
		check(not Geometry2D.triangulate_polygon(band).is_empty(), "Rounded fill bands are valid drawable polygons")
	check(not Geometry2D.is_point_in_polygon(Vector2(0.1,0.1), loops[0]), "Rounded corner actually changes fill silhouette")
	for shift in [100000.0, 10000000.0]:
		var translated := outer.duplicate()
		for i in range(translated.size()):
			translated[i].y += shift
		var distant_bands := Geometry.fill_bands([Geometry.rounded_loop(translated, 10)])
		var distant_area := 0.0
		for band in distant_bands:
			for i in range(band.size()):
				band[i].y -= shift
			distant_area += area(band)
		check(distant_area > 9900 and distant_area < 10000, "Distant floors retain all visible fill bands")
	print("Shape geometry tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
