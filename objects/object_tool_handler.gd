@tool
extends ConstructionToolHandler
## One reusable handler for object definitions; no food/bed cases in the editor.
@export var operation: StringName = &"object"
@export var definition: WorldObjectDefinition
func snap_policy() -> StringName:
	return &"cell_centers"
func instructions() -> String:
	if operation == &"move_object": return "Drag an object to another cell · Esc: cancel"
	return "Click: place at cell center · Right-click: remove · Esc: cancel"
func propose_edit(context: ConstructionContext,gesture: ConstructionGesture) -> ConstructionProposal:
	var proposal = ConstructionProposal.new()
	var command = preload("res://objects/object_edit_command.gd").new()
	command.operation = operation; command.definition = definition
	command.start = Vector2(gesture.start) + Vector2.ONE * 0.5
	command.endpoint = Vector2(gesture.end) + Vector2.ONE * 0.5
	command.erase = gesture.erase
	proposal.command = command
	proposal.valid = not context.model.physical.sweep(command.endpoint,command.endpoint,0.2).hit or gesture.erase
	if operation == &"move_object": proposal.valid = proposal.valid and context.model.simulation.objects.nearest(command.start) != null
	var center = command.endpoint * context.cell_size
	proposal.preview = {"markers":PackedVector2Array([center]),"label":("Move object" if operation == &"move_object" else "Polygon" if operation == &"agent" else definition.display_name),"label_position":center}
	return proposal
