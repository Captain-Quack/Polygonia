class_name StructureCodec
extends RefCounted
static func encode(data: StructureData) -> Dictionary:
	var walls: Array = []
	var doors: Array = []
	for r in data.get_walls():
		walls.append({"id":r.id,"a":[r.a.x,r.a.y],"b":[r.b.x,r.b.y],"material":str(r.material)})
	for r in data.get_doors():
		if r.has("circle_id"):
			doors.append({"id":r.id,"circle_id":r.circle_id,"offset":r.offset,"state":str(r.state),"locked":r.locked})
			continue
		doors.append({"id":r.id,"a":[r.a.x,r.a.y],"b":[r.b.x,r.b.y],"state":str(r.state),"locked":r.locked})
	var result={"version":1,"next_id":data.next_id,"walls":walls,"doors":doors}
	if not data.get_circles().is_empty():
		result.version=2;result.circles=[]
		for c in data.get_circles():result.circles.append({"id":c.id,"center":[c.center.x,c.center.y],"radius":c.radius,"segments":c.segments})
	return result
static func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and absf(float(value))<9007199254740991.0
static func point(value) -> bool:
	return value is Array and value.size()==2 and integer(value[0]) and integer(value[1]) and absf(float(value[0]))<=StructureData.LIMIT and absf(float(value[1]))<=StructureData.LIMIT
static func decode(payload: Dictionary) -> Dictionary:
	var bad := {"valid":false,"reason":&"INVALID_PAYLOAD","data":null}
	if payload.get("version") not in [1,2] or not integer(payload.get("next_id")) or payload.next_id<1: return bad
	if not payload.get("walls") is Array or not payload.get("doors") is Array: return bad
	var data := StructureData.new()
	data.next_id = int(payload.next_id)
	if payload.version==2:
		if not payload.get("circles") is Array:return bad
		for c in payload.circles:
			if not c is Dictionary or not integer(c.get("id")) or not point(c.get("center")) or not integer(c.get("radius")) or not integer(c.get("segments")):return bad
			data._circles.append({"id":int(c.id),"center":Vector2i(c.center[0],c.center[1]),"radius":float(c.radius),"segments":int(c.segments)})
	for kind in ["walls","doors"]:
		for r in payload[kind]:
			if kind=="doors" and r is Dictionary and r.has("circle_id"):
				if payload.version!=2 or not integer(r.get("id")) or not integer(r.circle_id) or not (r.get("offset") is float or r.get("offset") is int) or not is_finite(float(r.offset)) or not r.get("state") is String or not r.get("locked") is bool:return bad
				data._doors.append({"id":int(r.id),"a":Vector2.ZERO,"b":Vector2.ZERO,"circle_id":int(r.circle_id),"offset":float(r.offset),"state":StringName(r.state),"locked":r.locked})
				continue
			if not r is Dictionary or not integer(r.get("id")) or not point(r.get("a")) or not point(r.get("b")): return bad
			var record = {"id":int(r.id),"a":Vector2i(r.a[0],r.a[1]),"b":Vector2i(r.b[0],r.b[1])}
			if kind == "walls":
				if r.get("material") != "solid": return bad
				record.material = &"solid"
				data._walls.append(record)
			else:
				if not r.get("state") is String or not r.get("locked") is bool: return bad
				record.state = StringName(r.state); record.locked = r.locked
				data._doors.append(record)
	var reason = data.validate()
	if reason != &"": return {"valid":false,"reason":reason,"data":null}
	# Serialized wall records must already be disjoint along each supporting line.
	for i in range(data._walls.size()):
		for j in range(i):
			var a = data._walls[i]; var b = data._walls[j]
			if StructureData.collinear(a,b) and StructureData.low(a)<=StructureData.high(b) and StructureData.low(b)<=StructureData.high(a): return bad
	return {"valid":true,"reason":&"","data":data}
