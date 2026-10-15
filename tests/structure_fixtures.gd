extends RefCounted
static func rectangle(model,a: Vector2i,b: Vector2i) -> void:
	var C = load("res://structures/structure_command.gd")
	for pair in [[a,Vector2i(b.x,a.y)],[Vector2i(b.x,a.y),b],[b,Vector2i(a.x,b.y)],[Vector2i(a.x,b.y),a]]:
		model.execute(C.wall(pair[0],pair[1],false))
static func two_rooms(model) -> void:
	rectangle(model,Vector2i.ZERO,Vector2i(8,4))
	model.execute(load("res://structures/structure_command.gd").wall(Vector2i(4,0),Vector2i(4,4),false))
