class_name AgentCombatSystem
extends RefCounted
var _queued: Array = []
var _next_strike: Dictionary = {}
func queue_strike(actor_id: int,target_id: int,feeding: bool) -> void:
	_queued.append({"actor":actor_id,"target":target_id,"feeding":feeding})
func resolve(simulation: AgentSimulation) -> Array:
	var events: Array = []
	var damage: Dictionary = {}
	var used: Dictionary = {}
	var profile = simulation._profile
	# Validate every strike before any health mutation; simultaneous deaths are symmetric.
	for strike in _queued:
		var actor = simulation.get_agent(strike.actor)
		var target = simulation.get_agent(strike.target)
		if actor == null or target == null or actor == target: continue
		if not actor.body.alive() or not target.body.alive() or used.has(actor.id): continue
		if simulation.time < float(_next_strike.get(actor.id,0)): continue
		if actor.position.distance_to(target.position) > actor.radius+target.radius+profile.contact_margin: continue
		if not simulation.model.physical.has_line_of_sight(actor.position,target.position): continue
		used[actor.id] = true
		_next_strike[actor.id] = simulation.time+profile.strike_interval
		var amount = profile.strike_damage*(1-.5*actor.body.deprivation)
		damage[target.id] = float(damage.get(target.id,0))+amount
		target.threats[actor.id] = {"position":actor.position,"until":simulation.time+3.0}
		target.agent_beliefs[actor.id] = AgentPerception.agent_snapshot(actor,simulation.time)
		target.next_decision = simulation.time
		target.remember_event("Attacked by Polygon %d." % actor.id)
		strike.position = target.position
		strike.direction = (target.position-actor.position).normalized()
		strike.amount = amount
		events.append(strike)
	for id in damage:
		var target = simulation.get_agent(id)
		target.body.damage(damage[id])
		if not target.body.alive(): target.controller.cancel(target); target.action = &"dead"
	for event in events: simulation.gore.hit(event.target,event.position,event.direction,event.amount)
	_queued.clear()
	return events
func forget(id: int) -> void:
	_next_strike.erase(id)
	_queued = _queued.filter(func(s): return s.actor != id and s.target != id)
