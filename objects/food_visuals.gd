class_name FoodVisuals
extends RefCounted
## Cached layouts keep the visible circle count equal to the remaining food.
static var _one := PackedVector2Array([Vector2.ZERO])
static var _two := PackedVector2Array([Vector2(-.1,0),Vector2(.1,0)])
static var _three := PackedVector2Array([Vector2(-.1,.07),Vector2(.1,.07),Vector2(0,-.1)])
static var _empty := PackedVector2Array()
static func offsets(morsels: int) -> PackedVector2Array:
	match morsels:
		1: return _one
		2: return _two
		3: return _three
	return _empty
static func count(object: PolygonWorldObject) -> int:
	for provider in object.providers:
		if provider is FoodInteractionProvider: return provider.portion_count()
	return 3
