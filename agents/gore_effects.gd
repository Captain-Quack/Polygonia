class_name AgentGoreEffects
extends RefCounted
## Bounded presentation data. Uses its own RNG and never changes agent/world state.
const MAX_PARTICLES := 192
const MAX_STAINS := 384
const MAX_ACTORS := 128
const STAIN_LIFE := 90.0
var enabled := true:
	set(value):
		enabled = value
		if not value: clear()
var time := 0.0
var particles: Array = []
var stains: Array = []
var _actors: Dictionary = {}
var _stain_cells: Dictionary = {}
var _rng := RandomNumberGenerator.new()
func _init() -> void:
	_rng.seed = 620137
func clear() -> void:
	particles.clear(); stains.clear(); _actors.clear(); _stain_cells.clear()
func actor_count() -> int:
	return _actors.size()
func remove_actor(id: int) -> void:
	_actors.erase(id)
func _actor(id: int,position: Vector2) -> Dictionary:
	if not _actors.has(id):
		if _actors.size() >= MAX_ACTORS: _actors.erase(_actors.keys()[0])
		_actors[id] = {"hit_at":-INF,"bite_at":-INF,"wound_until":0.0,"blood_until":0.0,"trail_at":position,"next_drop":0.0}
	return _actors[id]
func _mark(position: Vector2,radius: float,opacity: float = .45,born: float = -1) -> void:
	if born < 0: born = time
	if time-born >= STAIN_LIFE: return
	var key = Vector2i((position*5).floor())
	if _stain_cells.has(key):
		var mark: Dictionary = _stain_cells[key]
		mark.radius = minf(.45,sqrt(mark.radius*mark.radius+radius*radius*.3))
		mark.opacity = minf(.55,maxf(mark.opacity,opacity))
		mark.born = maxf(mark.born,born)
		return
	if stains.size() >= MAX_STAINS:
		_stain_cells.erase(stains[0].key); stains.pop_front()
	var shape := PackedVector2Array()
	for i in range(9): shape.append(Vector2.from_angle(i*TAU/9)*_rng.randf_range(.65,1.0))
	var mark = {"key":key,"position":position,"radius":minf(.45,radius),"opacity":minf(.55,opacity),"born":born,"shape":shape,"angle":_rng.randf_range(-PI,PI)}
	stains.append(mark); _stain_cells[key] = mark
func _burst(position: Vector2,direction: Vector2,drops: int,chips: int) -> void:
	for i in range(drops+chips):
		if particles.size() >= MAX_PARTICLES: particles.pop_front()
		var chip = i >= drops
		var velocity = direction.rotated(_rng.randf_range(-1.15,1.15))*_rng.randf_range(.35,1.8)
		if direction == Vector2.ZERO: velocity = Vector2.from_angle(_rng.randf_range(-PI,PI))*_rng.randf_range(.25,1.1)
		particles.append({"position":position,"velocity":velocity,"born":time,"life":_rng.randf_range(.3,.85),"radius":_rng.randf_range(.025,.065) if chip else _rng.randf_range(.014,.036),"chip":chip,"angle":_rng.randf_range(-PI,PI)})
func hit(id: int,position: Vector2,direction: Vector2,damage: float) -> void:
	if not enabled or not is_finite(damage) or damage <= 0: return
	var actor = _actor(id,position)
	actor.hit_at = time; actor.wound_until = time+6; actor.blood_until = time+60
	_burst(position,direction.normalized(),10,2)
	_mark(position,.12)
func wounded(id: int) -> bool:
	return enabled and _actors.has(id) and _actors[id].wound_until > time
func death(id: int,position: Vector2,violent: bool) -> void:
	if not enabled: return
	if violent:
		_burst(position,Vector2.ZERO,30,10)
		_mark(position,.4,.55)
	_actors.erase(id)
func bite(id: int,position: Vector2,eater_position: Vector2) -> void:
	if not enabled: return
	var actor = _actor(id,eater_position)
	actor.bite_at = time; actor.blood_until = time+60
	_burst(position,(eater_position-position).normalized(),6,3)
	_mark(position,.15,.5)
func follow(agent: PolygonAgent) -> void:
	if not enabled or not _actors.has(agent.id) or not agent.body.alive(): return
	var actor: Dictionary = _actors[agent.id]
	if time >= actor.wound_until or time < actor.next_drop: return
	if agent.position.distance_to(actor.trail_at) < .15: return
	_mark(agent.position,.045,.45)
	actor.trail_at = agent.position; actor.next_drop = time+.15
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	time += delta
	if not enabled: return
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary = particles[i]
		if time-p.born < p.life: continue
		var landing: Vector2 = p.position+p.velocity*(1-exp(-3*p.life))/3.0
		_mark(landing,p.radius*(1.3 if p.chip else 1.8),.5,p.born+p.life)
		particles.remove_at(i)
	for i in range(stains.size()-1,-1,-1):
		if time-stains[i].born >= STAIN_LIFE:
			_stain_cells.erase(stains[i].key); stains.remove_at(i)
	for id in _actors.keys():
		if time >= _actors[id].blood_until: _actors.erase(id)
func appearance(id: int,at: float = -1) -> Dictionary:
	if at < 0: at = time
	var actor: Dictionary = _actors.get(id,{})
	var flash = clampf(1-maxf(0,at-float(actor.get("hit_at",-INF)))/.18,0,1)
	var bite_age = at-float(actor.get("bite_at",-INF))
	var bite = sin(clampf(bite_age/.3,0,1)*PI) if bite_age >= 0 and bite_age < .3 else 0.0
	return {"flash":flash,"bite":bite,"blood":clampf((float(actor.get("blood_until",0))-at)/20,0,1)}
