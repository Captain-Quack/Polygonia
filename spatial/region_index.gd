class_name RegionIndex
extends RefCounted
## Structural partitions only. Outdoor places need not map to a bounded region.
var _regions: Array=[{"id":0,"outer":[],"holes":[],"bounded":false,"area":INF,"portal_ids":[],"signature":"exterior"}]
var _portals: Array=[]
var _walls: Array=[]
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
		var p=points[(best+i)%points.size()];parts.append("%d,%d"%[p.x,p.y])
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
		if (w.a.y==w.b.y and point.y==w.a.y and point.x>=w.a.x and point.x<=w.b.x) or (w.a.x==w.b.x and point.x==w.a.x and point.y>=w.a.y and point.y<=w.b.y):
			var ids: Array=[]
			# Integer walls partition unit cells. Sample only cells incident to
			# this point, so a nearby junction cannot introduce another room.
			var xs=[floorf(point.x)+.5]
			var ys=[floorf(point.y)+.5]
			if point.x==floorf(point.x):xs.append(point.x-.5)
			if point.y==floorf(point.y):ys.append(point.y-.5)
			for x in xs:
				for y in ys:
					var id=_interior_id(Vector2(x,y))
					if not ids.has(id):ids.append(id)
			return {"kind":&"BOUNDARY","region_id":-1,"incident_region_ids":ids}
	return {"kind":&"REGION","region_id":_interior_id(point),"incident_region_ids":[]}
func rebuild(data: StructureData) -> Dictionary:
	rebuild_count+=1
	var old=_regions
	_walls=data.get_walls()
	var arrangement=RectilinearArrangement.build(_walls,data.get_doors())
	var fresh: Array=[{"id":0,"outer":[],"holes":[],"bounded":false,"area":INF,"portal_ids":[],"signature":"exterior"}]
	var negative: Array=[]
	for ring in arrangement.cycles:
		var a=RectilinearArrangement.area(ring)
		if a>0:fresh.append({"id":-1,"outer":ring,"holes":[],"bounded":true,"area":a,"portal_ids":[],"signature":""})
		else:negative.append(ring)
	for ring in negative:
		var delta=Vector2(ring[1]-ring[0]).normalized()
		var sample=(Vector2(ring[0])+Vector2(ring[1]))*.5+Vector2(-delta.y,delta.x)*.25
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
		var midpoint=(Vector2(d.a)+Vector2(d.b))*.5
		var direction=Vector2(d.b-d.a).normalized()
		var normal=Vector2(-direction.y,direction.x)*.25
		var portal={"id":d.id,"region_a":_interior_id(midpoint+normal),"region_b":_interior_id(midpoint-normal),"a":d.a,"b":d.b}
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
			if (a.y>y)!=(b.y>y):xs.append(a.x)
	xs.sort();var result: Array=[]
	for i in range(0,xs.size(),2):result.append(Vector2(xs[i],xs[i+1]))
	return result
static func overlap_area(a: Dictionary,b: Dictionary) -> float:
	var levels: Dictionary={}
	for ring in [a.outer,b.outer]+a.holes+b.holes:
		for p in ring:levels[p.y]=true
	var ys=levels.keys();ys.sort();var total=0.0
	for i in range(ys.size()-1):
		var y=(float(ys[i])+float(ys[i+1]))*.5
		for x in intervals(a,y):
			for z in intervals(b,y):
				total+=maxf(0,minf(x.y,z.y)-maxf(x.x,z.x))*(ys[i+1]-ys[i])
	return total
