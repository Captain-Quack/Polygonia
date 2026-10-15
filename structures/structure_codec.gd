class_name StructureCodec
extends RefCounted
static func encode(data: StructureData) -> Dictionary:
	var walls: Array = []
	var doors: Array = []
	for r in data.get_walls():
		walls.append({"id":r.id,"a":[r.a.x,r.a.y],"b":[r.b.x,r.b.y],"material":str(r.material)})
	for r in data.get_doors():
		doors.append({"id":r.id,"a":[r.a.x,r.a.y],"b":[r.b.x,r.b.y],"state":str(r.state),"locked":r.locked})
	return {"version":1,"next_id":data.next_id,"walls":walls,"doors":doors}
static func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and absf(float(value))<9007199254740991.0
static func point(value) -> bool:
	return value is Array and value.size()==2 and integer(value[0]) and integer(value[1]) and absf(float(value[0]))<=StructureData.LIMIT and absf(float(value[1]))<=StructureData.LIMIT
static func decode(payload: Dictionary) -> Dictionary:
	var bad := {"valid":false,"reason":&"INVALID_PAYLOAD","data":null}
	if payload.get("version") != 1 or not integer(payload.get("next_id")) or payload.next_id<1: return bad
	if not payload.get("walls") is Array or not payload.get("doors") is Array: return bad
	var data := StructureData.new()
	data.next_id = int(payload.next_id)
	for kind in ["walls","doors"]:
		for r in payload[kind]:
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
