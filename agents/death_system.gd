class_name AgentDeathSystem
extends RefCounted
static func materialize(agent: PolygonAgent,simulation: AgentSimulation) -> void:
	if agent.body.alive() or agent.death_handled: return
	agent.death_handled = true
	agent.controller.cancel(agent); agent.action = &"dead"
	simulation.combat.forget(agent.id)
	var definition = load("res://objects/definitions/corpse.tres").duplicate(true)
	definition.interactions[0].nourishment = simulation.profile().edible_yield
	definition.interactions[0].duration = simulation.profile().consumption_duration
	var corpse = simulation.objects.add(definition,agent.position)
	if corpse != null: agent.corpse_id = corpse.id
