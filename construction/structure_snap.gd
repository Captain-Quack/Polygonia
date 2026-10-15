class_name StructureSnap
extends RefCounted
## Shared join targets for orthogonal strokes, including partial-arc endpoints.
static func targets(context: ConstructionContext) -> Array:
	var result: Array=[]
	for c in context.model.structures.get_circles():
		if not c.has("ranges"):continue
		var points=context.model.structures.circle_points(c)
		for span in context.model.structures.circle_ranges(c):
			var path=CircleBoundary.slice(points,span[0],span[1]-span[0])
			result.append(path[0]);result.append(path[-1])
	for wall in context.model.structures.get_walls():
		result.append(Vector2(wall.a));result.append(Vector2(wall.b))
	for loop in context.model.floors.boundary_loops():
		for p in loop:result.append(Vector2(p))
	return result
static func nearest(context: ConstructionContext,raw: Vector2,fallback: Vector2,candidates: Array,axis: int=-1,constant: float=0.0) -> Vector2:
	var distance=10.0/(context.cell_size*context.camera_scale);var result=fallback
	for p in candidates:
		if axis>=0 and absf(p[axis]-constant)>.00001:continue
		var candidate=raw.distance_to(p)
		# Authoritative structure endpoints precede quantized floor vertices.
		# Treat their subpixel contour roundoff as a tie.
		if candidate<distance-.0005:
			distance=candidate;result=p
	return result
