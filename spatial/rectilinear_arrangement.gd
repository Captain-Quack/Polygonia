class_name RectilinearArrangement
extends RefCounted
## Half-edge arrangement for straight and sampled curved structural edges.
## Retains the legacy class name for consumers.
static func area(ring: Array) -> float:
	if ring.size()<3:return 0.0
	var origin=Vector2(ring[0]);var twice=0.0
	for i in range(ring.size()):
		var a=Vector2(ring[i])-origin;var b=Vector2(ring[(i+1)%ring.size()])-origin
		twice+=SegmentGeometry.cross(a,b)
	return twice*.5
static func simplify(ring: Array) -> Array:
	var result=ring.duplicate();var changed=true
	while changed and result.size()>2:
		changed=false
		for i in range(result.size()):
			var a=Vector2(result[i])-Vector2(result[posmod(i-1,result.size())])
			var b=Vector2(result[(i+1)%result.size()])-Vector2(result[i])
			if absf(SegmentGeometry.cross(a,b))<SegmentGeometry.EPS*maxf(a.length(),b.length()):
				result.remove_at(i);changed=true;break
	return result
static func build(walls: Array,_doors: Array) -> Dictionary:
	var cuts: Array=[]
	for w in walls:cuts.append([Vector2(w.a),Vector2(w.b)])
	for i in range(walls.size()):
		var a=Vector2(walls[i].a);var b=Vector2(walls[i].b)
		for j in range(i):
			for p in SegmentGeometry.intersections(a,b,Vector2(walls[j].a),Vector2(walls[j].b)):
				cuts[i].append(p);cuts[j].append(p)
	var edges: Array=[];var outgoing: Dictionary={};var unique: Dictionary={}
	for wall_index in range(cuts.size()):
		var points=cuts[wall_index]
		points.sort_custom(func(a,b):return a.x<b.x or (a.x==b.x and a.y<b.y))
		for i in range(points.size()-1):
			var a=points[i];var b=points[i+1]
			if a==b:continue
			var key=[a,b]
			if unique.has(key):continue
			unique[key]=true
			var k=edges.size()
			edges.append({"a":a,"b":b,"twin":k+1,"source":walls[wall_index]});edges.append({"a":b,"b":a,"twin":k,"source":walls[wall_index]})
			if not outgoing.has(a):outgoing[a]=[]
			if not outgoing.has(b):outgoing[b]=[]
			outgoing[a].append(k);outgoing[b].append(k+1)
	for vertex in outgoing:
		outgoing[vertex].sort_custom(func(i,j):return (edges[i].b-vertex).angle()<(edges[j].b-vertex).angle())
	var seen: Dictionary={};var cycles: Array=[]
	for first in range(edges.size()):
		if seen.has(first):continue
		var walk: Array=[];var current=first
		while not seen.has(current):
			seen[current]=true
			var e=edges[current];walk.append(e.a)
			var candidates: Array=outgoing[e.b]
			current=candidates[posmod(candidates.find(e.twin)-1,candidates.size())]
		walk.append(edges[first].a)
		var stack: Array=[]
		for p in walk:
			var at=stack.find(p)
			if at>=0:
				var cycle=simplify(stack.slice(at))
				if cycle.size()>=3 and absf(area(cycle))>0.0000001:cycles.append(cycle)
				stack=stack.slice(0,at+1)
			else:stack.append(p)
	return {"half_edges":edges,"cycles":cycles,"vertices":outgoing.keys()}
