extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	if not ResourceLoader.exists("res://objects/food_visuals.gd"):
		check(false,"food drawing has distinct layouts for three, two, and one circle")
		quit(1); return
	var visuals = load("res://objects/food_visuals.gd")
	for count in range(4):
		var points: PackedVector2Array = visuals.offsets(count)
		check(points.size() == count,"render exactly %d circles" % count)
		if count > 0:
			var center := Vector2.ZERO
			for point in points: center += point
			check(center.length() < .05,"remaining circles are centered")
	var food = PolygonWorldObject.new(load("res://objects/definitions/food.tres"))
	check(visuals.count(food) == 3,"original food starts as three circles")
	food.providers[0].begin(1)
	var small = food.providers[0].split_one(1,2)
	check(visuals.count(food) == 2,"giving one circle changes donor rendering")
	food.providers[0].complete(1)
	check(visuals.count(food) == 0,"depletion draws no circles")
	check(small.portion_count() == 1,"recipient renders one independently consumable circle")
	print("food_visuals: %d failures" % failures); quit(1 if failures else 0)
