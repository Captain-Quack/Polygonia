class_name CircleBoundary
extends RefCounted
## Shared sampling: floor Circle and structural Circle use identical vertices.
static func points(center: Vector2,radius: float,count: int) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for i in range(count):
		var offset=Vector2.from_angle(TAU*i/count)*radius
		if i==0:offset=Vector2(radius,0)
		elif i==count/4:offset=Vector2(0,radius)
		elif i==count/2:offset=Vector2(-radius,0)
		elif i==count*3/4:offset=Vector2(0,-radius)
		result.append(center+offset)
	return result
static func length(path: PackedVector2Array,closed: bool=false) -> float:
	var result=0.0
	for i in range(path.size() if closed else path.size()-1):result+=path[i].distance_to(path[(i+1)%path.size()])
	return result
static func slice(path: PackedVector2Array,start: float,width: float) -> PackedVector2Array:
	var total=length(path,true)
	var cursor=fposmod(start,total)
	var result:=PackedVector2Array()
	for lap in range(2):
		for i in range(path.size()):
			var a=path[i];var b=path[(i+1)%path.size()];var span=a.distance_to(b)
			if cursor>=span:cursor-=span;continue
			if result.is_empty():result.append(a.lerp(b,cursor/span))
			var take=minf(width,span-cursor)
			var endpoint=a.lerp(b,(cursor+take)/span)
			if endpoint.distance_to(result[-1])>0.000001:result.append(endpoint)
			width-=take;cursor=0.0
			if width<0.000001:return result
	return result
static func project(path: PackedVector2Array,p: Vector2,closed: bool=true) -> Dictionary:
	var best={"distance":INF,"offset":0.0,"point":Vector2.ZERO}
	var offset=0.0
	for i in range(path.size() if closed else path.size()-1):
		var a=path[i];var b=path[(i+1)%path.size()]
		var q=Geometry2D.get_closest_point_to_segment(p,a,b)
		var distance=p.distance_to(q)
		if distance<best.distance:best={"distance":distance,"offset":offset+a.distance_to(q),"point":q}
		offset+=a.distance_to(b)
	return best
static func middle(path: PackedVector2Array) -> Dictionary:
	var remaining=length(path)*.5
	for i in range(path.size()-1):
		var span=path[i].distance_to(path[i+1])
		if remaining<=span:return {"point":path[i].lerp(path[i+1],remaining/span),"direction":(path[i+1]-path[i]).normalized()}
		remaining-=span
	return {"point":path[0],"direction":Vector2.RIGHT}
