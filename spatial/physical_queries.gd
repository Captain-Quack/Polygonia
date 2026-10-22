class_name PhysicalQueries
extends RefCounted
const WALL_RADIUS:=0.05
var model
var open_cost:=1.0
var _cached_revision:=-1
var _segments: Array=[]
func segments() -> Array:
	_ensure_segments()
	return _segments.duplicate(true)
func _ensure_segments() -> void:
	if _cached_revision==model.structures.barrier_revision:return
	_segments=[]
	var doors=model.structures.get_doors()
	for wall in model.structures.get_walls():
		var pieces: Array=[[Vector2(wall.a),Vector2(wall.b)]]
		for d in doors:
			if d.has("circle_id"):continue
			var path=StructureData.door_path(d)
			for i in range(path.size()-1):
				var remaining: Array=[]
				for piece in pieces:remaining.append_array(SegmentGeometry.subtract(piece[0],piece[1],path[i],path[i+1]))
				pieces=remaining
		for piece in pieces:_segments.append({"a":piece[0],"b":piece[1],"id":wall.id,"door":false})
	# Cut circles by their authoritative path distances. Testing rounded
	# interpolated door points for collinearity can leave invisible fragments.
	for circle in model.structures.get_circles():
		var points=model.structures.circle_points(circle)
		var total=CircleBoundary.length(points,true)
		var intervals: Array=model.structures.circle_ranges(circle)
		for d in doors:
			if d.get("circle_id",0)!=circle.id:continue
			var cuts: Array=[[d.offset,minf(total,d.offset+1.0)]]
			if d.offset+1.0>total:cuts.append([0.0,d.offset+1.0-total])
			for cut in cuts:
				var remaining: Array=[]
				for span in intervals:
					if cut[1]<=span[0] or cut[0]>=span[1]:remaining.append(span);continue
					if cut[0]>span[0]:remaining.append([span[0],cut[0]])
					if cut[1]<span[1]:remaining.append([cut[1],span[1]])
				intervals=remaining
		for span in intervals:
			var path=CircleBoundary.slice(points,span[0],span[1]-span[0])
			for i in range(path.size()-1):_segments.append({"a":path[i],"b":path[i+1],"id":circle.id,"door":false})
	for d in doors:
		if d.state==&"CLOSED":
			var path=StructureData.door_path(d)
			for i in range(path.size()-1):_segments.append({"a":path[i],"b":path[i+1],"id":d.id,"door":true})
	_cached_revision=model.structures.barrier_revision
static func _box_time(px: float,py: float,vx: float,vy: float,length: float,radius: float) -> float:
	var entry=0.0;var exit=1.0
	for axis in [[px,vx,0.0,length],[py,vy,-radius,radius]]:
		if absf(axis[1])<1e-15:
			if axis[0]<axis[2] or axis[0]>axis[3]:return INF
		else:
			var a=(axis[2]-axis[0])/axis[1];var b=(axis[3]-axis[0])/axis[1]
			entry=maxf(entry,minf(a,b));exit=minf(exit,maxf(a,b))
			if entry>exit:return INF
	return entry
static func _circle_time(px: float,py: float,vx: float,vy: float,radius: float) -> float:
	var c=px*px+py*py-radius*radius
	if c<=0:return 0.0
	var a=vx*vx+vy*vy
	if a==0:return INF
	# Perpendicular distance avoids subtracting almost equal squared terms
	# in the quadratic discriminant on very long, nearly tangent sweeps.
	var cross=px*vy-py*vx
	var distance_squared=cross*cross/a
	if distance_squared>radius*radius:return INF
	var closest_time=-(px*vx+py*vy)/a
	var time=closest_time-sqrt((radius*radius-distance_squared)/a)
	return time if time>=0 and time<=1 else INF
static func capsule_time(from: Vector2,to: Vector2,a: Vector2,b: Vector2,radius: float) -> float:
	var dx=float(b.x)-a.x;var dy=float(b.y)-a.y
	var length=sqrt(dx*dx+dy*dy)
	if length==0:return _circle_time(float(from.x)-a.x,float(from.y)-a.y,float(to.x)-from.x,float(to.y)-from.y,radius)
	var ux=dx/length;var uy=dy/length
	var x=float(from.x)-a.x;var y=float(from.y)-a.y
	var vx=float(to.x)-from.x;var vy=float(to.y)-from.y
	var px=x*ux+y*uy;var py=-x*uy+y*ux
	var tx=vx*ux+vy*uy;var ty=-vx*uy+vy*ux
	return minf(_box_time(px,py,tx,ty,length,radius),minf(_circle_time(px,py,tx,ty,radius),_circle_time(px-length,py,tx,ty,radius)))

func _hits(from: Vector2,to: Vector2,radius: float,ignore_id: int=0) -> Array:
	var result: Array=[]
	_ensure_segments()
	for segment in _segments:
		if segment.id==ignore_id:continue
		if not bounds_overlap(from,to,segment.a,segment.b,radius+WALL_RADIUS):continue
		var time=capsule_time(from,to,segment.a,segment.b,radius+WALL_RADIUS)
		if not is_finite(time):continue
		var position=from+(to-from)*time
		var closest=Geometry2D.get_closest_point_to_segment(position,segment.a,segment.b)
		var normal=(position-closest).normalized()
		if normal==Vector2.ZERO:normal=(from-to).normalized()
		result.append({"valid":true,"reason":&"","hit":true,"position":position,"normal":normal,"entity_id":segment.id,"barrier_revision":model.structures.barrier_revision,"time":time})
	result.sort_custom(func(a,b):return a.time<b.time or (a.time==b.time and a.entity_id<b.entity_id))
	return result
func sweep(from: Vector2,to: Vector2,radius: float) -> Dictionary:
	if not StructureData.in_range(from) or not StructureData.in_range(to) or not is_finite(radius) or radius<0:
		return {"valid":false,"reason":&"INVALID_QUERY","hit":false}
	var hits=_hits(from,to,radius)
	return hits[0] if not hits.is_empty() else {"valid":true,"reason":&"","hit":false,"barrier_revision":model.structures.barrier_revision}
func visibility_hits(from: Vector2,to: Vector2) -> Array:
	if not StructureData.in_range(from) or not StructureData.in_range(to):return [{"valid":false,"reason":&"INVALID_QUERY","hit":false}]
	return _hits(from,to,0)
## Boolean query avoids allocating, sorting and describing every hit.
func has_line_of_sight(from: Vector2,to: Vector2) -> bool:
	_ensure_segments()
	return sight_in_segments(from,to,_segments)
## Trusted perception uses these references only during its immutable observation phase.
func _sight_segments(point: Vector2,radius: float) -> Array:
	_ensure_segments()
	var extent=Vector2.ONE*radius
	var nearby: Array=[]
	for segment in _segments:
		if bounds_overlap(point-extent,point+extent,segment.a,segment.b,WALL_RADIUS): nearby.append(segment)
	return nearby
static func sight_in_segments(from: Vector2,to: Vector2,candidates: Array) -> bool:
	if not StructureData.in_range(from) or not StructureData.in_range(to):return false
	for segment in candidates:
		if not bounds_overlap(from,to,segment.a,segment.b,WALL_RADIUS):continue
		if is_finite(capsule_time(from,to,segment.a,segment.b,WALL_RADIUS)):return false
	return true
## Conservative broad phase; touching bounds must still reach the exact query.
static func bounds_overlap(from: Vector2,to: Vector2,a: Vector2,b: Vector2,radius: float) -> bool:
	return maxf(from.x,to.x)+radius >= minf(a.x,b.x) and minf(from.x,to.x)-radius <= maxf(a.x,b.x) and maxf(from.y,to.y)+radius >= minf(a.y,b.y) and minf(from.y,to.y)-radius <= maxf(a.y,b.y)
func crossing_option(door_id: int,profile: Dictionary) -> Dictionary:
	var result={"kind":&"BLOCKED","reason":&"MISSING_DOOR","door_id":door_id,"action_cost":0.0}
	var door=model.structures.get_door(door_id)
	if door.is_empty():return result
	var radius=float(profile.get("radius",0.2))
	if not is_finite(radius) or radius<0:result.reason=&"INVALID_QUERY";return result
	if door.locked:result.reason=&"LOCKED";return result
	if door.state==&"CLOSED" and not profile.get("can_open_doors",false):result.reason=&"CANNOT_OPEN";return result
	var middle=CircleBoundary.middle(StructureData.door_path(door))
	var midpoint=middle.point
	var direction=middle.direction
	var normal=Vector2(-direction.y,direction.x)*(radius+WALL_RADIUS+.1)
	if not _hits(midpoint-normal,midpoint+normal,radius,door_id).is_empty():result.reason=&"INSUFFICIENT_CLEARANCE";return result
	result.kind=&"PASS" if door.state==&"OPEN" else &"OPEN_THEN_PASS"
	result.reason=&"";result.action_cost=0.0 if door.state==&"OPEN" else open_cost
	return result

