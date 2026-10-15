class_name RegionIndex
extends RefCounted
## Structural partitions only. Outdoor places need not map to a bounded region.
var _regions: Array=[{"id":0,"outer":[],"holes":[],"bounded":false,"area":INF,"portal_ids":[],"signature":"exterior"}]
var _portals: Array=[]
var _walls: Array=[]
var _edges: Array=[]
var next_id:=1
var rebuild_count:=0
var last_change: Dictionary={"preserved_ids":[],"removed_ids":[],"created_ids":[],"overlap_links":[],"exterior_transition_ids":[]}
func get_regions() -> Array:return _regions.duplicate(true)
func get_portals() -> Array:return _portals.duplicate(true)
func region(id: int) -> Dictionary:
	for r in _regions:
		if r.id==id:return r.duplicate(true)
	return {}
static func inside(p: Vector2,ring: Array) -> bool:
	var hit=false
	for i in range(ring.size()):
		var a=ring[i];var b=ring[(i+1)%ring.size()]
		if (a.y>p.y)!=(b.y>p.y):
			var x=float(a.x)+((float(p.y)-float(a.y))/(float(b.y)-float(a.y)))*(float(b.x)-float(a.x))
			if float(p.x)<x:hit=not hit
	return hit
static func signature(ring: Array) -> String:
	var points=RectilinearArrangement.simplify(ring)
	var best=0
	for i in range(points.size()):
		if points[i].x<points[best].x or (points[i].x==points[best].x and points[i].y<points[best].y):best=i
	var parts=PackedStringArray()
	for i in range(points.size()):
		var p=points[(best+i)%points.size()];parts.append("%.6f,%.6f"%[p.x,p.y])
	return ";".join(parts)
func _interior_id(p: Vector2) -> int:
	for r in _regions:
		if not r.bounded or not inside(p,r.outer):continue
		var hole=false
		for h in r.holes:
			if inside(p,h):hole=true;break
		if not hole:return r.id
	return 0
func locate(point: Vector2) -> Dictionary:
	if not StructureData.in_range(point):return {"kind":&"OUT_OF_RANGE","region_id":-1,"incident_region_ids":[]}
	for w in _walls:
		if SegmentGeometry.on(point,Vector2(w.a),Vector2(w.b)):
			return {"kind":&"BOUNDARY","region_id":-1,"incident_region_ids":_boundary_ids(point)}
	return {"kind":&"REGION","region_id":_interior_id(point),"incident_region_ids":[]}
func _sample_distance(point: Vector2) -> float:
	var distance=.125
	# Midpoints/interpolated paths are Vector2 (float32). Ignore roundoff
	# from their own incident edges instead of shrinking the sample to zero.
	var tolerance=maxf(SegmentGeometry.EPS,maxf(absf(point.x),absf(point.y))*0.00000012)
	for e in _edges:
		for endpoint in [e.a,e.b]:
			var span=point.distance_to(endpoint)
			if span>tolerance:distance=minf(distance,span*.25)
		var separation=point.distance_to(Geometry2D.get_closest_point_to_segment(point,e.a,e.b))
		if separation>tolerance:distance=minf(distance,separation*.25)
	return distance
func _edge_regions(edge: Dictionary) -> Array:
	# Ring orientations already encode the two faces of every boundary edge.
	# Read incidence from the graph, without numerically offsetting a point.
	var ids: Array=[]
	for r in _regions:
		if not r.bounded:continue
		var touches=false
		for ring in [r.outer]+r.holes:
			for i in range(ring.size()):
				if SegmentGeometry.on(edge.a,Vector2(ring[i]),Vector2(ring[(i+1)%ring.size()])) and SegmentGeometry.on(edge.b,Vector2(ring[i]),Vector2(ring[(i+1)%ring.size()])):
					touches=true;break
			if touches:break
		if touches:ids.append(r.id)
	if ids.size()==1:ids.append(0)
	if ids.is_empty():ids.append(_interior_id((edge.a+edge.b)*.5))
	return ids
func _boundary_ids(point: Vector2) -> Array:
	var ids: Array=[]
	for e in _edges:
		if not SegmentGeometry.on(point,e.a,e.b):continue
		for id in _edge_regions(e):
			if not ids.has(id):ids.append(id)
	return ids
func _portal_regions(door: Dictionary) -> Array:
	var cuts: Array=[]
	if door.has("circle_id"):
		var total=CircleBoundary.length(_circle_paths[door.circle_id],true)
		cuts.append([door.offset,minf(total,door.offset+1.0)])
		if door.offset+1.0>total:cuts.append([0.0,door.offset+1.0-total])
	for e in _edges:
		var source=e.source
		if door.has("circle_id"):
			if source.get("circle_id",0)!=door.circle_id:continue
			var x=source.offset+Vector2(source.a).distance_to(e.a)
			var y=source.offset+Vector2(source.a).distance_to(e.b)
			var overlaps=false
			for cut in cuts:
				if minf(maxf(x,y),cut[1])-maxf(minf(x,y),cut[0])>SegmentGeometry.EPS:overlaps=true;break
			if not overlaps:continue
		else:
			if source.has("circle_id") or not StructureData.collinear(door,source):continue
			var x=e.a.x if door.a.y==door.b.y else e.a.y
			var y=e.b.x if door.a.y==door.b.y else e.b.y
			if minf(maxf(x,y),StructureData.high(door))-maxf(minf(x,y),StructureData.low(door))<=0:continue
		var ids=_edge_regions(e)
		return [ids[0],ids[1] if ids.size()>1 else ids[0]]
	return [0,0]
var _circle_paths: Dictionary={}

func rebuild(data: StructureData) -> Dictionary:
	rebuild_count+=1
	var old=_regions
	_walls=data.get_wall_segments()
	_circle_paths.clear()
	for circle in data.get_circles():_circle_paths[circle.id]=data.circle_points(circle)
	var arrangement=RectilinearArrangement.build(_walls,data.get_doors())
	_edges=arrangement.half_edges
	var fresh: Array=[{"id":0,"outer":[],"holes":[],"bounded":false,"area":INF,"portal_ids":[],"signature":"exterior"}]
	var negative: Array=[]
	for ring in arrangement.cycles:
		var a=RectilinearArrangement.area(ring)
		if a>0:fresh.append({"id":-1,"outer":ring,"holes":[],"bounded":true,"area":a,"portal_ids":[],"signature":""})
		else:negative.append(ring)
	for ring in negative:
		var delta=Vector2(ring[1]-ring[0]).normalized()
		var midpoint=(Vector2(ring[0])+Vector2(ring[1]))*.5
		var sample=midpoint+Vector2(-delta.y,delta.x)*_sample_distance(midpoint)
		var owner=-1;var smallest=INF
		for i in range(1,fresh.size()):
			if inside(sample,fresh[i].outer) and fresh[i].area<smallest:
				owner=i;smallest=fresh[i].area
		if owner>=0:fresh[owner].holes.append(ring)
	for r in fresh:
		if not r.bounded:continue
		var holes=PackedStringArray()
		for h in r.holes:
			r.area+=RectilinearArrangement.area(h);holes.append(signature(h))
		holes.sort()
		r.signature=signature(r.outer)+"|"+"|".join(holes)
		for previous in old:
			if previous.signature==r.signature:r.id=previous.id;break
		if r.id<0:r.id=next_id;next_id+=1
	_regions=fresh
	_portals=[]
	for d in data.get_doors():
		var ids=_portal_regions(d)
		var portal={"id":d.id,"region_a":ids[0],"region_b":ids[1],"a":d.a,"b":d.b}
		_portals.append(portal)
		for r in _regions:
			if r.id==portal.region_a or r.id==portal.region_b:r.portal_ids.append(d.id)
	last_change={"preserved_ids":[0],"removed_ids":[],"created_ids":[],"overlap_links":[],"exterior_transition_ids":[]}
	for previous in old:
		if not previous.bounded:continue
		if fresh.any(func(r):return r.id==previous.id):last_change.preserved_ids.append(previous.id)
		else:last_change.removed_ids.append(previous.id)
	for r in fresh:
		if not r.bounded or last_change.preserved_ids.has(r.id):continue
		last_change.created_ids.append(r.id)
	for previous in old:
		if not last_change.removed_ids.has(previous.id):continue
		var covered=0.0
		for r in fresh:
			if not r.bounded or not last_change.created_ids.has(r.id):continue
			var overlap=overlap_area(previous,r)
			if overlap>0:
				last_change.overlap_links.append({"old_id":previous.id,"new_id":r.id,"area":overlap});covered+=overlap
		if covered<previous.area:last_change.exterior_transition_ids.append(previous.id)
	for r in fresh:
		if not last_change.created_ids.has(r.id):continue
		var covered=0.0
		for link in last_change.overlap_links:
			if link.new_id==r.id:covered+=link.area
		if covered<r.area:last_change.exterior_transition_ids.append(r.id)
	return last_change.duplicate(true)
static func intervals(r: Dictionary,y: float) -> Array:
	var xs: Array=[]
	for ring in [r.outer]+r.holes:
		for i in range(ring.size()):
			var a=ring[i];var b=ring[(i+1)%ring.size()]
			if (a.y>y)!=(b.y>y):xs.append(float(a.x)+(y-float(a.y))/(float(b.y)-a.y)*(float(b.x)-a.x))
	xs.sort();var result: Array=[]
	for i in range(0,xs.size(),2):result.append(Vector2(xs[i],xs[i+1]))
	return result
static func overlap_area(a: Dictionary,b: Dictionary) -> float:
	var levels: Dictionary={}
	for ring in [a.outer,b.outer]+a.holes+b.holes:
		for p in ring:levels[p.y]=true
	# Interval overlap ordering also changes where old/new sloping edges cross.
	for aring in [a.outer]+a.holes:
		for bring in [b.outer]+b.holes:
			for i in range(aring.size()):
				for j in range(bring.size()):
					for p in SegmentGeometry.intersections(Vector2(aring[i]),Vector2(aring[(i+1)%aring.size()]),Vector2(bring[j]),Vector2(bring[(j+1)%bring.size()])):levels[p.y]=true
	var ys=levels.keys();ys.sort();var total=0.0
	for i in range(ys.size()-1):
		var y=(float(ys[i])+float(ys[i+1]))*.5
		for x in intervals(a,y):
			for z in intervals(b,y):
				total+=maxf(0,minf(x.y,z.y)-maxf(x.x,z.x))*(ys[i+1]-ys[i])
	return total
