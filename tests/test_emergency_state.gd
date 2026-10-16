extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	if not ResourceLoader.exists("res://agents/emergency_assessment.gd"):
		check(false,"emergency assessment exists"); quit(1); return
	var assessment = load("res://agents/emergency_assessment.gd")
	var profile = load("res://agents/emergency_profile.gd").new()
	var body = PolygonBody.new()
	body.nourishment = 0
	check(is_equal_approx(assessment.evaluate(body,profile).fatal_after,50),"zero nourishment gives fifty seconds at full health")
	body.health = .12
	check(is_equal_approx(assessment.evaluate(body,profile).fatal_after,6),"low health shortens survival window")
	body.starvation_damage = 0
	check(is_inf(assessment.evaluate(body,profile).fatal_after),"zero damage has infinite deadline")
	body.starvation_damage = .02; body.hunger_rate = 0; body.nourishment = .05
	check(is_equal_approx(assessment.damage_over(body,2),.02),"constant low nourishment still damages")
	body.health = 1; body.nourishment = 0
	body.tick_deprivation(60,profile)
	check(is_equal_approx(body.deprivation,.5),"deprivation accumulates over time")
	body.apply_effects({&"nourishment":.45})
	check(is_equal_approx(body.deprivation,.5),"meal does not reset impairment")
	body.tick_deprivation(90,profile)
	check(is_zero_approx(body.deprivation),"sustained nutrition permits gradual recovery")
	profile.buildup_seconds = 0
	check(not profile.validate().is_empty(),"invalid profile rejected")
	profile.buildup_seconds = 120
	body.nourishment = .3; body.hunger_rate = .004
	var small = PolygonBody.new(); small.nourishment = .3
	body.tick_deprivation(40,profile)
	for i in range(400):
		small.tick_deprivation(.1,profile); small.nourishment -= .0004
	check(absf(body.deprivation-small.deprivation)<.0001,"deprivation integrates threshold crossings")
	var traits = load("res://agents/personality.gd")
	var a = traits.from_seed(7,1); var b = traits.from_seed(7,1)
	check(a.aggression == b.aggression and a.caution == b.caution,"seeded traits reproduce")
	print("emergency_state: %d failures" % failures); quit(1 if failures else 0)
