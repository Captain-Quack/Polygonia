extends RefCounted
var operation: StringName
var definition: WorldObjectDefinition
var start := Vector2.ZERO
var endpoint := Vector2.ZERO
var erase := false
func execute(model: WorldModel) -> StructureChange:
	var result = StructureChange.new()
	var sim: AgentSimulation = model.simulation
	if operation == &"move_object":
		var object = sim.objects.nearest(start)
		if object == null: result.reason = &"NO_OBJECT"; return result
		if model.physical.sweep(endpoint,endpoint,0.2).hit: result.reason = &"BLOCKED"; return result
		result.accepted = sim.objects.move(object.id,endpoint)
	elif operation == &"agent":
		if erase:
			for agent in sim.agents:
				if agent.position.distance_to(endpoint) < 0.7:
					sim.remove(agent.id); result.accepted = true; break
		else: result.accepted = sim.spawn(endpoint) != null
	else:
		if erase:
			var object = sim.objects.nearest(endpoint,0.7,definition.definition_id)
			if object != null: result.accepted = sim.objects.remove(object.id)
		elif not model.physical.sweep(endpoint,endpoint,0.2).hit:
			result.accepted = sim.objects.add(definition,endpoint) != null
	return result
