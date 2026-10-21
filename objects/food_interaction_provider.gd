class_name FoodInteractionProvider
extends InteractionProvider
const MORSELS := 3
var _morsels := MORSELS
func claimed() -> bool:
	return active and not _users.is_empty()
func portion_count() -> int:
	return _morsels if active and stock != 0 else 0
func split_one(owner: int,recipient: int) -> FoodInteractionProvider:
	# Only a finite, admitted meal may be divided. Leave at least one morsel.
	if not active or stock != 1 or not has_user(owner) or recipient <= 0 or recipient == owner or _morsels < 2: return null
	var portion = FoodInteractionProvider.new(definition)
	portion.stock = 1; portion._morsels = 1
	if not portion.begin(recipient): return null
	_morsels -= 1
	return portion
func meal_effects() -> Dictionary:
	var effects = definition.effects()
	for key in effects: effects[key] *= float(_morsels)/MORSELS
	return effects
func complete(actor: int) -> Dictionary:
	if not active or not has_user(actor) or stock == 0: return {}
	var effects = meal_effects()
	super.complete(actor)
	if stock == 0: _morsels = 0
	return effects
func observation() -> Dictionary:
	var result = super.observation()
	result.effects = meal_effects()
	result.morsels = portion_count()
	result.holders = _users.keys()
	result.divisible_food = true
	return result
