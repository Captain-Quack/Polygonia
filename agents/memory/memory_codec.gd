class_name AgentMemoryCodec
extends RefCounted
## JSON-safe, clock-relative format. Decode into temporary stores before committing.
const SCHEMAS := {
	"places":["cell","at","visited","familiarity","food","rest","danger","access","confidence"],
	"people":["id","at","familiarity","help","harm","confidence"],
	"habits":["action","cell","at","success","relief","error","confidence"],
	"episodes":["kind","position","at","started","actor","source","amount","expected","witnessed","salience"]}
const LIMITS := {"places":64,"people":24,"habits":16,"episodes":32}
const TIMES := ["at","visited","started"]
static func encode(memory,now: float) -> Dictionary:
	var result = {"version":1,"scarcity":memory.scarcity,"body_age":maxf(0,now-memory.last_body_at)}
	for table in SCHEMAS:
		var rows: Array = memory.get(table) if table=="episodes" else memory.get(table).values()
		result[table] = []
		for row in rows:
			var encoded = row.duplicate()
			for field in TIMES:
				if encoded.has(field): encoded[field] = maxf(0,now-float(encoded[field]))
			for field in ["cell","position"]:
				if encoded.has(field): encoded[field]=[encoded[field].x,encoded[field].y]
			result[table].append(encoded)
	return result
static func _number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))
static func decode(data: Dictionary,now: float) -> Dictionary:
	if not is_finite(now) or data.get("version")!=1 or not _number(data.get("scarcity")) or not _number(data.get("body_age")): return {}
	if data.scarcity<0 or data.scarcity>1 or data.body_age<0 or data.body_age>1e12: return {}
	var result = {"scarcity":data.scarcity,"last_body_at":now-float(data.body_age)}
	for table in SCHEMAS:
		var rows = data.get(table)
		if not rows is Array or rows.size()>LIMITS[table]: return {}
		result[table] = [] if table=="episodes" else {}
		for original in rows:
			if not original is Dictionary or original.size()!=SCHEMAS[table].size(): return {}
			var row = original.duplicate(true)
			for field in SCHEMAS[table]:
				if not row.has(field): return {}
				var value = row[field]
				if field in ["cell","position"]:
					if not value is Array or value.size()!=2 or not _number(value[0]) or not _number(value[1]): return {}
					if absf(value[0])>1000000 or absf(value[1])>1000000: return {}
					if field=="cell" and (value[0]!=floorf(value[0]) or value[1]!=floorf(value[1])): return {}
					row[field] = Vector2i(int(value[0]),int(value[1])) if field=="cell" else Vector2(value[0],value[1])
				elif field=="witnessed":
					if not value is bool: return {}
				elif field in ["kind","action"]:
					if not (value is String or value is StringName): return {}
					if field=="kind" and not StringName(value) in AgentExperienceMemory.KINDS: return {}
					if field=="action" and not value in ["eat","rest","escape"]: return {}
					row[field]=StringName(value)
				else:
					if not _number(value): return {}
					if field in TIMES:
						if value<0 or value>1e12: return {}
						row[field]=now-float(value)
					elif field in ["id","actor","source"]:
						if value<0 or value>2147483647 or value!=floorf(value) or (field=="id" and value==0): return {}
						row[field]=int(value)
					elif value>1 or value<(-1 if field in ["access","error"] else 0): return {}
			if table=="episodes":
				if row.started>row.at: return {}
				result[table].append(row)
			else:
				var key = row.id if table=="people" else row.cell if table=="places" else "%s:%d:%d" % [row.action,row.cell.x,row.cell.y]
				if result[table].has(key): return {}
				result[table][key]=row
	return result
