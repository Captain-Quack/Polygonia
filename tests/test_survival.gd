extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	if not ResourceLoader.exists("res://agents/body_state.gd"):
		check(false,"Survival body exists"); quit(1); return
	var body = load("res://agents/body_state.gd").new()
	body.nourishment = 0.5
	body.tick(10.0)
	check(body.nourishment < 0.5 and body.fatigue > 0,"time increases hunger and fatigue")
	check(body.health == 1.0,"ordinary hunger does not damage health")
	body.nourishment = 0.0
	body.tick(10.0)
	check(body.health < 1.0,"severe deprivation damages health")
	body.apply_effects({&"nourishment": 2.0})
	check(body.nourishment == 1.0,"nutrition is clamped")
	body.damage(5.0)
	body.apply_effects({&"nourishment": 1.0})
	check(not body.alive() and body.health == 0.0,"dead body remains dead")
	var store = load("res://objects/object_store.gd").new()
	var definition = load("res://objects/definitions/food.tres")
	var food = store.add(definition,Vector2(2,0))
	var other = store.add(definition,Vector2(3,0))
	var p = food.providers[0]
	p.stock = 1
	check(p.begin(1),"first agent reserves food")
	check(not p.begin(2),"capacity prevents simultaneous consumption")
	check(p.complete(2).is_empty(),"non-owner cannot consume reserved food")
	check(p.complete(1).get(&"nourishment",0) > 0,"reserved completion gives nutrition")
	check(p.stock == 0 and not p.begin(2),"last portion cannot be consumed twice")
	check(other.providers[0].stock > 0,"instances do not share mutable stock")
	var rest = store.add(load("res://objects/definitions/rest.tres"),Vector2.ZERO)
	check(rest.providers[0].begin(1),"rest capacity reservable")
	rest.providers[0].cancel(1)
	check(rest.providers[0].begin(2),"cancellation releases capacity")
	check(store.move(food.id,Vector2(4,0)) and food.position == Vector2(4,0),"move preserves identity")
	store.remove(rest.id)
	check(not rest.active and rest.providers[0].complete(2).is_empty(),"removed resource invalidates interaction")
	print("survival: %d failures" % failures); quit(1 if failures else 0)
