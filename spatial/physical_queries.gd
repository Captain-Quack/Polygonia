class_name PhysicalQueries
extends RefCounted
const WALL_RADIUS:=0.05
var model
var open_cost:=1.0
var _cached_revision:=-1
var _segments: Array=[]
func segments() -> Array:
	if _cached_revision==model.structures.barrier_revision:return _segments.duplicate(true)
	_segments=[]
	var doors=model.structures.get_doors()
	for wall in model.structures.get_walls():
		var intervals: Array=[Vector2i(StructureData.low(wall),StructureData.high(wall))]
		for d in doors:
			if not StructureData.collinear(wall,d):continue
			var next: Array=[]
			for part in intervals:
				var lo=maxi(part.x,StructureData.low(d));var hi=mini(part.y,StructureData.high(d))
				if hi<=lo:next.append(part)
				else:
					if part.x<lo:next.append(Vector2i(part.x,lo))
					if hi<part.y:next.append(Vector2i(hi,part.y))
			intervals=next
		for part in intervals:
			var piece=StructureData.subrun(wall,part.x,part.y)
			_segments.append({"a":Vector2(piece.a),"b":Vector2(piece.b),"id":piece.id,"door":false})
	for d in doors:
		if d.state==&"CLOSED":_segments.append({"a":Vector2(d.a),"b":Vector2(d.b),"id":d.id,"door":true})
	_cached_revision=model.structures.barrier_revision
	return _segments.duplicate(true)
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
	var horizontal=a.y==b.y
	var p=from-a;var v=to-from
	var px=float(p.x if horizontal else p.y);var py=float(p.y if horizontal else p.x)
	var vx=float(v.x if horizontal else v.y);var vy=float(v.y if horizontal else v.x)
	var length=float(b.x-a.x if horizontal else b.y-a.y)
	return minf(_box_time(px,py,vx,vy,length,radius),minf(_circle_time(px,py,vx,vy,radius),_circle_time(px-length,py,vx,vy,radius)))
func _hits(from: Vector2,to: Vector2,radius: float,ignore_id: int=0) -> Array:
	var result: Array=[]
	for segment in segments():
		if segment.id==ignore_id:continue
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
func crossing_option(door_id: int,profile: Dictionary) -> Dictionary:
	var result={"kind":&"BLOCKED","reason":&"MISSING_DOOR","door_id":door_id,"action_cost":0.0}
	var door=model.structures.get_door(door_id)
	if door.is_empty():return result
	var radius=float(profile.get("radius",0.2))
	if not is_finite(radius) or radius<0:result.reason=&"INVALID_QUERY";return result
	if door.locked:result.reason=&"LOCKED";return result
	if door.state==&"CLOSED" and not profile.get("can_open_doors",false):result.reason=&"CANNOT_OPEN";return result
	var midpoint=(Vector2(door.a)+Vector2(door.b))*.5
	var direction=Vector2(door.b-door.a).normalized()
	var normal=Vector2(-direction.y,direction.x)*(radius+WALL_RADIUS+.1)
	if not _hits(midpoint-normal,midpoint+normal,radius,door_id).is_empty():result.reason=&"INSUFFICIENT_CLEARANCE";return result
	result.kind=&"PASS" if door.state==&"OPEN" else &"OPEN_THEN_PASS"
	result.reason=&"";result.action_cost=0.0 if door.state==&"OPEN" else open_cost
	return result
