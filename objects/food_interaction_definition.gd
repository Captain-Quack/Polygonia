class_name FoodInteractionDefinition
extends InteractionDefinition
## One serving is divisible into three visible morsels, with the same total effect.
func create_provider() -> InteractionProvider:
	return FoodInteractionProvider.new(self)
