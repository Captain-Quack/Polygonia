extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var body := PolygonBody.new()
	for n in [0.0,.001,.05,.1,.4,1.0]:
		for health in [.0001,.02,.5,1.0]:
			for drain in [0.0,.0001,.004,1.0]:
				body.nourishment = n; body.health = health; body.hunger_rate = drain
				var deadline := EmergencyAssessment.fatal_after(body)
				if is_finite(deadline):
					check(absf(EmergencyAssessment.damage_over(body,deadline)-health)<.0000001,"deadline integrates to remaining health")
					check(EmergencyAssessment.damage_over(body,deadline*.999)<health,"deadline is earliest fatal time")
				else: check(drain == 0 and n >= body.starvation_threshold,"only non-damaging states survive indefinitely")
	var world := WorldModel.new()
	world.execute(StructureCommand.wall(Vector2i(0,-2),Vector2i(0,2),false))
	world.execute(StructureCommand.circle(Vector2i(5,0),2,32))
	var random := RandomNumberGenerator.new(); random.seed = 981
	for i in range(200):
		var a := Vector2(random.randf_range(-5,9),random.randf_range(-5,5))
		var b := Vector2(random.randf_range(-5,9),random.randf_range(-5,5))
		# Include stationary and tangent sweeps as well as random diagonals.
		if i == 0: a = Vector2.ZERO; b = a
		if i == 1: a = Vector2(-2,2.25); b = Vector2(2,2.25)
		if i == 2: a = Vector2(-2,2.05); b = Vector2(2,2.05)
		var exact_sight := true
		var exact_sweep := false
		for segment in world.physical.segments():
			if is_finite(PhysicalQueries.capsule_time(a,b,segment.a,segment.b,PhysicalQueries.WALL_RADIUS)): exact_sight = false
			if is_finite(PhysicalQueries.capsule_time(a,b,segment.a,segment.b,.2+PhysicalQueries.WALL_RADIUS)): exact_sweep = true
		check(world.physical.has_line_of_sight(a,b) == exact_sight,"boolean sight matches unpruned exact geometry")
		check(world.physical.sweep(a,b,.2).hit == exact_sweep,"broad phase preserves exact body collision")
	check(not world.physical.has_line_of_sight(Vector2(INF,0),Vector2.ZERO),"invalid sight is blocked")
	var copy := world.physical.segments()
	copy[0].a = Vector2(100,100); copy.clear()
	check(not world.physical.has_line_of_sight(Vector2(-1,0),Vector2(1,0)),"public geometry copies cannot corrupt internal cache")
	world.execute(StructureCommand.wall(Vector2i(0,-2),Vector2i(0,2),true))
	check(world.physical.has_line_of_sight(Vector2(-1,0),Vector2(1,0)),"barrier edits immediately refresh boolean sight")
	var observer := PolygonAgent.new(); observer.sight_range = -1
	check(not AgentPerception.visible(observer,Vector2.ZERO,world),"negative sight range sees nothing")
	world.free()
	print("agent_query_equivalence: %d failures" % failures); quit(1 if failures else 0)
