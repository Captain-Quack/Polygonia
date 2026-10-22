class_name AgentExperienceMemory
extends RefCounted
## Personal evidence only. No references to live actors, objects, rooms or routes.
const PLACE_SIZE := 2.0
const PLACE_LIMIT := 64
const PERSON_LIMIT := 24
const HABIT_LIMIT := 16
const EPISODE_LIMIT := 32
const KINDS := [&"meal",&"rested",&"attacked",&"received",&"gave",&"missing",&"blocked",&"interrupted",&"escaped"]
var places: Dictionary = {}
var people: Dictionary = {}
var habits: Dictionary = {}
var episodes: Array = []
var time := 0.0
var scarcity := 0.0
var last_body_at := -1000000.0
var revision := 0
static func cell(point: Vector2) -> Vector2i:
	return Vector2i((point/PLACE_SIZE).floor())
static func habit_key(action: StringName,point: Vector2) -> String:
	var c = cell(point)
	return "%s:%d:%d" % [action,c.x,c.y]
func place(point: Vector2,now: float) -> Dictionary:
	var r: Dictionary = places.get(cell(point),{"cell":cell(point),"at":now,"visited":-1000000.0,"familiarity":0.0,"food":0.0,"rest":0.0,"danger":0.0,"access":0.0,"confidence":0.0})
	return _aged(r,now,["familiarity","food","rest","danger","access","confidence"])
func person(id: int,now: float) -> Dictionary:
	return _aged(people.get(id,{"id":id,"at":now,"familiarity":0.0,"help":0.0,"harm":0.0,"confidence":0.0}),now,["familiarity","help","harm","confidence"])
func habit(action: StringName,point: Vector2,now: float) -> Dictionary:
	var r: Dictionary = habits.get(habit_key(action,point),{"action":action,"cell":cell(point),"at":now,"success":0.5,"relief":0.0,"error":0.0,"confidence":0.0})
	var result = _aged(r,now,["relief","error","confidence"])
	result.success = .5+(float(r.success)-.5)*exp(-maxf(0,now-float(r.at))/900.0)
	return result
static func _aged(record: Dictionary,now: float,fields: Array) -> Dictionary:
	var result = record.duplicate()
	var decay = exp(-maxf(0,now-float(record.at))/900.0)
	for field in fields: result[field] = float(record[field])*decay
	result.at = now
	return result
func visit(point: Vector2,now: float,safe: bool) -> void:
	time = now
	var p = place(point,now)
	if now-float(p.visited) < 1.0: return
	p.visited = now
	p.familiarity = minf(1,p.familiarity+.05)
	if safe: p.danger *= .94
	places[cell(point)] = p
	_trim(places,PLACE_LIMIT)
	revision += 1
func sample_body(nourishment: float,now: float) -> void:
	time = now
	var dt = minf(2,maxf(0,now-last_body_at))
	if dt < 1: return
	last_body_at = now
	if nourishment < .2: scarcity = minf(1,scarcity+dt*(.2-nourishment)/12.0)
	elif nourishment > .5: scarcity = maxf(0,scarcity-dt/120.0)
func record(kind: StringName,point: Vector2,now: float,actor: int = 0,source: int = 0,amount: float = 1.0,witnessed: bool = false,expected: float = 0.0) -> void:
	if not kind in KINDS or not point.is_finite() or not is_finite(now) or not is_finite(amount) or not is_finite(expected) or actor < 0 or source < 0: return
	time = now
	# A continuous encounter remains one episode even while it moves through patches.
	for i in range(episodes.size()-1,-1,-1):
		var e: Dictionary = episodes[i]
		if now-float(e.at)>8: continue
		if kind!=&"meal" and e.kind==kind and e.actor==actor and e.source==source and e.witnessed==witnessed and (actor>0 or cell(e.position)==cell(point)):
			e.at = now
			return
	var weight = .45 if witnessed else 1.0
	var p = place(point,now)
	p.confidence = minf(1,p.confidence+.2*weight)
	match kind:
		&"meal": p.food = lerpf(p.food,1.0,.35*weight); p.access = lerpf(p.access,1.0,.2*weight)
		&"rested": p.rest = lerpf(p.rest,1.0,.35*weight); p.danger *= .8
		&"attacked": p.danger = lerpf(p.danger,1.0,.65*weight)
		&"missing": p.food *= .4
		&"blocked": p.access = lerpf(p.access,-1.0,.3*weight)
		&"escaped": p.access = lerpf(p.access,1.0,.2*weight)
	places[cell(point)] = p; _trim(places,PLACE_LIMIT)
	if actor>0:
		var person_record = person(actor,now)
		person_record.familiarity = minf(1,person_record.familiarity+.15*weight)
		person_record.confidence = minf(1,person_record.confidence+.25*weight)
		if kind==&"received": person_record.help = lerpf(person_record.help,1.0,.4*weight)
		if kind==&"attacked": person_record.harm = lerpf(person_record.harm,1.0,.65*weight)
		people[actor] = person_record; _trim(people,PERSON_LIMIT)
	var action: StringName = &"eat" if kind==&"meal" else &"rest" if kind==&"rested" else &"escape" if kind==&"escaped" else &""
	if action!=&"":
		var h = habit(action,point,now)
		h.success = lerpf(h.success,1.0,.3)
		h.relief = lerpf(h.relief,clampf(amount,0,1),.35)
		h.error = lerpf(h.error,clampf(amount-expected,-1,1),.35)
		h.confidence = minf(1,h.confidence+.2)
		habits[habit_key(action,point)] = h; _trim(habits,HABIT_LIMIT)
	var salience = 1.0 if kind==&"attacked" else .8 if kind==&"received" else .45
	episodes.append({"kind":kind,"position":point,"at":now,"started":now,"actor":actor,"source":source,"amount":clampf(amount,0,1),"expected":clampf(expected,0,1),"witnessed":witnessed,"salience":salience*weight})
	if episodes.size()>EPISODE_LIMIT:
		var least := INF; var index := 0
		for i in range(episodes.size()):
			var priority = float(episodes[i].salience)/(1+maxf(0,now-float(episodes[i].at))/60.0)
			if priority<least: least=priority; index=i
		episodes.remove_at(index)
	revision += 1
func failure(action: StringName,point: Vector2,now: float) -> void:
	var h = habit(action,point,now)
	h.success = lerpf(h.success,0.0,.25); h.confidence = minf(1,h.confidence+.1)
	habits[habit_key(action,point)] = h; _trim(habits,HABIT_LIMIT)
static func _trim(table: Dictionary,limit: int) -> void:
	while table.size()>limit:
		var victim = table.keys()[0]; var oldest := INF
		for key in table:
			var r: Dictionary = table[key]
			var priority = float(r.at)+30*maxf(float(r.get("danger",0)),maxf(float(r.get("harm",0)),float(r.get("help",0))))
			if priority<oldest: oldest=priority; victim=key
		table.erase(victim)
func snapshot(now: float) -> Dictionary:
	return AgentMemoryCodec.encode(self,now)
func restore(data: Dictionary,now: float) -> bool:
	var decoded = AgentMemoryCodec.decode(data,now)
	if decoded.is_empty(): return false
	places=decoded.places; people=decoded.people; habits=decoded.habits; episodes=decoded.episodes
	scarcity=decoded.scarcity; last_body_at=decoded.last_body_at; time=now; revision+=1
	return true
