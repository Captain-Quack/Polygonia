class_name RectilinearArrangement
extends RefCounted
## Half-edge arrangement. Coordinates use the usual algebraic orientation;
## Godot's downward screen y changes visual handedness, not the face algorithm.
static func area(ring: Array) -> float:
	if ring.size()<3: return 0.0
	var origin: Vector2i=ring[0]
	var twice: int=0
	for i in range(ring.size()):
		var a: Vector2i=ring[i]-origin
		var b: Vector2i=ring[(i+1)%ring.size()]-origin
		twice+=int(a.x)*int(b.y)-int(a.y)*int(b.x)
	return float(twice)*0.5
static func simplify(ring: Array) -> Array:
	var result=ring.duplicate()
	var changed=true
	while changed and result.size()>2:
		changed=false
		for i in range(result.size()):
			var a: Vector2i=result[i]-result[posmod(i-1,result.size())]
			var b: Vector2i=result[(i+1)%result.size()]-result[i]
			if int(a.x)*b.y-int(a.y)*b.x==0:
				result.remove_at(i);changed=true;break
	return result
static func build(walls: Array,doors: Array) -> Dictionary:
	var cuts: Array=[]
	for w in walls: cuts.append([w.a,w.b])
	for i in range(walls.size()):
		var a=walls[i]
		for d in doors:
			if StructureData.collinear(a,d) and StructureData.low(a)<=StructureData.low(d) and StructureData.high(a)>=StructureData.high(d):
				cuts[i].append(d.a);cuts[i].append(d.b)
		for j in range(i):
			var b=walls[j]
			if (a.a.y==a.b.y)==(b.a.y==b.b.y): continue
			var h=a if a.a.y==a.b.y else b
			var v=b if a.a.y==a.b.y else a
			if v.a.x>=h.a.x and v.a.x<=h.b.x and h.a.y>=v.a.y and h.a.y<=v.b.y:
				var point=Vector2i(v.a.x,h.a.y)
				cuts[i].append(point);cuts[j].append(point)
	var edges: Array=[]
	var outgoing: Dictionary={}
	for points in cuts:
		points.sort_custom(func(a,b):return a.x<b.x or (a.x==b.x and a.y<b.y))
		for i in range(points.size()-1):
			var a: Vector2i=points[i];var b: Vector2i=points[i+1]
			if a==b:continue
			var k=edges.size()
			edges.append({"a":a,"b":b,"twin":k+1});edges.append({"a":b,"b":a,"twin":k})
			if not outgoing.has(a):outgoing[a]=[]
			if not outgoing.has(b):outgoing[b]=[]
			outgoing[a].append(k);outgoing[b].append(k+1)
	for vertex in outgoing:
		outgoing[vertex].sort_custom(func(i,j):return Vector2(edges[i].b-vertex).angle()<Vector2(edges[j].b-vertex).angle())
	var seen: Dictionary={}
	var cycles: Array=[]
	for first in range(edges.size()):
		if seen.has(first):continue
		var walk: Array=[]
		var current=first
		while not seen.has(current):
			seen[current]=true
			var e=edges[current];walk.append(e.a)
			var candidates: Array=outgoing[e.b]
			current=candidates[posmod(candidates.find(e.twin)-1,candidates.size())]
		walk.append(edges[first].a)
		# Split weak face walks at repeated vertices: bridge excursions have zero area.
		var stack: Array=[]
		for p in walk:
			var at=stack.find(p)
			if at>=0:
				var cycle=simplify(stack.slice(at))
				if cycle.size()>=3 and area(cycle)!=0:cycles.append(cycle)
				stack=stack.slice(0,at+1)
			else:stack.append(p)
	return {"half_edges":edges,"cycles":cycles,"vertices":outgoing.keys()}
