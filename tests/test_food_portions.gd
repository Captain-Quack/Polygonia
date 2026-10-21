extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var store = WorldObjectStore.new()
	var food = store.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	var provider = food.providers[0]
	if not provider.has_method("portion_count") or not store.has_method("share_food"):
		check(false,"food supports three conserved, separately visible portions")
		quit(1); return
	check(provider.portion_count() == 3 and provider.stock == 1,"one original serving contains three circles")
	check(provider.begin(1),"holder begins meal")
	var second = store.share_food(food.id,1,2,Vector2(.2,0))
	check(second != null,"holder can give away one circle")
	check(provider.portion_count() == 2 and second.providers[0].portion_count() == 1,"sharing produces two circles plus one")
	check(provider.has_user(1) and second.providers[0].has_user(2),"split preserves donor and recipient claims")
	var third = store.share_food(food.id,1,3,Vector2(0,.2))
	check(third != null and provider.portion_count() == 1,"second split produces three single circles")
	check(store.share_food(food.id,1,4,Vector2.ZERO) == null,"cannot give away the final circle")
	check(store.share_food(second.id,99,4,Vector2.ZERO) == null,"stranger cannot split another agent's meal")
	var nutrition := 0.0
	for pair in [[food,1],[second,2],[third,3]]:
		var p = pair[0].providers[0]
		nutrition += float(p.complete(pair[1]).get(&"nourishment",0))
		check(p.complete(pair[1]).is_empty(),"a split portion cannot be consumed twice")
		check(p.portion_count() == 0,"consumed circles disappear")
	check(is_equal_approx(nutrition,.45),"all three circles conserve the original nutrition")
	store.remove_depleted()
	check(store.all().is_empty(),"all consumed split piles are removed")
	food = store.add(load("res://objects/definitions/food.tres"),Vector2.ZERO)
	provider = food.providers[0]; provider.begin(1)
	check(store.share_food(food.id,1,2,Vector2(INF,0)) == null and provider.portion_count() == 3,"invalid split position cannot destroy food")
	provider.cancel(1)
	check(provider.portion_count() == 3 and provider.begin(2),"interrupted meals retain their food")
	var a = AgentPersonality.from_seed(1,1); var b = AgentPersonality.from_seed(1,1)
	check(a.get("kindness") != null and a.get("kindness") == b.get("kindness"),"kindness is a stable seeded trait")
	print("food_portions: %d failures" % failures); quit(1 if failures else 0)
