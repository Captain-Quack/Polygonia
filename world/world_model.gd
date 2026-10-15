class_name WorldModel
extends Node
signal structure_changed(change)
signal world_replaced(change)
var floors = preload("res://floors/floor_data.gd").new()
func execute(command: RefCounted) -> StructureChange:
	return command.execute(self)

var structures := StructureData.new()
var regions := RegionIndex.new()
func install_structure(next: StructureData, change: StructureChange, publish: bool=true) -> void:
	next.revision=structures.revision+1
	next.topology_revision=structures.topology_revision+int(change.topology_changed)
	next.barrier_revision=structures.barrier_revision+int(change.barrier_changed)
	next.traversal_revision=structures.traversal_revision+int(change.traversal_changed)
	structures=next
	change.revision=next.revision
	if change.topology_changed: regions.rebuild(structures)
	if publish:structure_changed.emit(change)

var simulation: AgentSimulation
var physical := PhysicalQueries.new()
var occupancy_query: Callable
func _init() -> void:
	physical.model=self
	simulation = AgentSimulation.new(self)
	occupancy_query = simulation.occupied

func replace_structures(payload: Dictionary) -> StructureChange:
	var result:=StructureChange.new()
	result.previous_revision=structures.revision;result.revision=structures.revision
	var decoded=StructureCodec.decode(payload)
	if not decoded.valid:result.reason=decoded.reason;return result
	result.accepted=true
	decoded.data.next_id=maxi(decoded.data.next_id,structures.next_id)
	result.before_state=StructureCodec.encode(structures);result.after_state=StructureCodec.encode(decoded.data)
	result.topology_changed=true;result.barrier_changed=true;result.traversal_changed=true
	install_structure(decoded.data,result,false)
	world_replaced.emit(result)
	return result
