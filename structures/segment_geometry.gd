class_name SegmentGeometry
extends RefCounted
const EPS:=0.00001
static func cross(a: Vector2,b: Vector2) -> float:return float(a.x)*b.y-float(a.y)*b.x
static func on(p: Vector2,a: Vector2,b: Vector2) -> bool:
	return absf(cross(p-a,b-a))<=EPS*maxf(1,a.distance_to(b)) and (p-a).dot(p-b)<=EPS*EPS
static func intersections(a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> Array:
	var r=b-a;var s=d-c;var det=cross(r,s)
	if absf(det)<=EPS*minf(r.length(),s.length()):
		var result: Array=[]
		for p in [a,b,c,d]:
			if on(p,a,b) and on(p,c,d) and not result.has(p):result.append(p)
		return result
	var t=cross(c-a,s)/det;var u=cross(c-a,r)/det
	if t<0 or t>1 or u<0 or u>1:return []
	# Reuse endpoint values exactly at T/corner joins.
	for p in [a,b]:
		if on(p,c,d):return [p]
	for p in [c,d]:
		if on(p,a,b):return [p]
	return [a+r*t]
static func subtract(a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> Array:
	var direction=(b-a).normalized();var span=a.distance_to(b)
	if absf(cross(c-a,direction))>EPS or absf(cross(d-a,direction))>EPS:return [[a,b]]
	var x=(c-a).dot(direction);var y=(d-a).dot(direction)
	var lo=maxf(0,minf(x,y));var hi=minf(span,maxf(x,y))
	if hi-lo<=EPS:return [[a,b]]
	var result: Array=[]
	if lo>EPS:result.append([a,a+direction*lo])
	if span-hi>EPS:result.append([a+direction*hi,b])
	return result
