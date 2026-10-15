class_name AgentRenderer
extends RefCounted
## Render-only geometry, independent of physiology or decisions.
static func rounded_triangle(radius: float) -> PackedVector2Array:
	var vertices: Array[Vector2] = []
	for i in range(3): vertices.append(Vector2.from_angle(i*TAU/3.0)*radius)
	var result = PackedVector2Array()
	for i in range(3):
		var corner = vertices[i]
		var before = corner.lerp(vertices[(i+2)%3],0.23)
		var after = corner.lerp(vertices[(i+1)%3],0.23)
		for j in range(7):
			var t = j/6.0
			result.append(before*(1-t)*(1-t) + corner*2*(1-t)*t + after*t*t)
	return result
