extends SceneTree
## Repeatable headless CPU benchmark. Timings are observations, not assertions.
func _initialize() -> void:
	for crowded in [false,true]:
		for count in [50,150]:
			var world := WorldModel.new()
			for i in range(20):
				world.execute(StructureCommand.wall(Vector2i(i*3,-4),Vector2i(i*3+1,-4),false))
			for i in range(count):
				var point := Vector2(i%15,i/15)*(.6 if crowded else 4.0)
				var agent = world.simulation.spawn(point)
				agent.body.nourishment = .015
				agent.body.deprivation = .5
				if i%3 == 0: world.simulation.objects.add(load("res://objects/definitions/food.tres"),point+Vector2(.4,.4))
			for i in range(5): world.simulation.tick(.1)
			var samples: Array[float] = []
			for i in range(30):
				var start := Time.get_ticks_usec()
				world.simulation.tick(.1)
				samples.append((Time.get_ticks_usec()-start)/1000.0)
			samples.sort()
			print("hungry agents=%d crowded=%s median=%.3f ms p95=%.3f ms" % [count,crowded,samples[15],samples[28]])
			# Include an untimed behavior digest for before/after comparison.
			var states: Array = []
			for agent in world.simulation.agents:
				states.append([agent.id,snappedf(agent.position.x,.00001),snappedf(agent.position.y,.00001),snappedf(agent.body.health,.00001),agent.action,agent.controller.current.get("key","")])
			print("behavior digest: "+JSON.stringify(states).sha256_text())
			world.free()
	var body := PolygonBody.new()
	body.nourishment = .05
	var start := Time.get_ticks_usec()
	for i in range(10000): EmergencyAssessment.fatal_after(body)
	print("10000 survival estimates: %.3f ms" % ((Time.get_ticks_usec()-start)/1000.0))
	quit()
