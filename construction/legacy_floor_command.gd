extends RefCounted
var handler: ConstructionToolHandler
var gesture: ConstructionGesture
func execute(model: WorldModel) -> StructureChange:
	handler.commit(model.floors, gesture.start, gesture.end, gesture.step, gesture.erase)
	var result := StructureChange.new()
	result.accepted = true
	return result
