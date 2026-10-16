extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	if not ResourceLoader.exists("res://agents/agent_motion.gd"):
		check(false,"Render interpolation exists"); quit(1); return
	var motion = load("res://agents/agent_motion.gd").new()
	motion.begin(Vector2(5,2),0)
	check(motion.sample(0.5).position == Vector2(5,2),"spawn renders at actual location")
	motion.begin(Vector2.ZERO,deg_to_rad(170))
	motion.record(Vector2(1,0),deg_to_rad(-170))
	check(motion.sample(0.25).position.is_equal_approx(Vector2(.25,0)),"visible movement advances between simulation ticks")
	check(motion.sample(0.75).position.is_equal_approx(Vector2(.75,0)),"successive render frames keep moving")
	check(absf(absf(motion.sample(0.5).facing)-PI) < .001,"rotation takes shortest arc")
	motion.record(Vector2(1,1),deg_to_rad(-170))
	check(motion.sample(0.25).position.is_equal_approx(Vector2(.5,0)),"interpolation follows first route segment")
	check(motion.sample(0.75).position.is_equal_approx(Vector2(1,.5)),"interpolation follows corner rather than cutting it")
	check(motion.sample(2).position == Vector2(1,1),"interpolation never overshoots")
	motion.begin(Vector2(1,1),0)
	check(motion.sample(0.5).position == Vector2(1,1),"stationary agent remains still")
	var model = WorldModel.new()
	var agent = model.simulation.spawn(Vector2.ZERO)
	agent.body.nourishment = .2
	model.simulation.objects.add(load("res://objects/definitions/food.tres"),Vector2(3,0))
	model.simulation.tick(.1)
	var sample = agent.motion.sample(.5)
	check(sample.position.x > 0 and sample.position.x < agent.position.x,"simulation records interpolatable movement")
	check(agent.position.x > sample.position.x,"render sampling does not modify simulation position")
	model.free()
	print("agent_motion: %d failures" % failures); quit(1 if failures else 0)
