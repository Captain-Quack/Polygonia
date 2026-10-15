class_name StructureCommand
extends RefCounted
var kind: StringName
var a := Vector2i.ZERO
var b := Vector2i.ZERO
var erase := false
var door_id := 0
var actor_id := 0
static func wall(start: Vector2i,end: Vector2i,remove: bool) -> StructureCommand:
	var c := StructureCommand.new(); c.kind = &"WALL"; c.a=start; c.b=end; c.erase=remove; return c
static func place_door(start: Vector2i,end: Vector2i) -> StructureCommand:
	var c := wall(start,end,false); c.kind = &"DOOR"; return c
static func remove_door(id: int) -> StructureCommand:
	var c := StructureCommand.new(); c.kind = &"REMOVE_DOOR"; c.door_id=id; return c
static func door_action(id: int,action: StringName,actor: int=0) -> StructureCommand:
	var c := StructureCommand.new();c.kind=action;c.door_id=id;c.actor_id=actor;return c
func evaluate(model) -> Dictionary:
	var stage: StructureData = model.structures.copy()
	var reason: StringName = &""
	if kind in [&"WALL",&"DOOR"]:
		if not StructureData.valid_segment(a,b): return {"reason":&"INVALID_SEGMENT","data":stage}
		var ends = StructureData.canonical(a,b)
		var run = {"id":0,"a":ends[0],"b":ends[1],"material":&"solid"}
		if kind == &"DOOR":
			stage._doors.append({"id":stage.allocate_id(),"a":run.a,"b":run.b,"state":&"CLOSED","locked":false})
		elif erase:
			var remaining: Array = []
			for w in stage._walls:
				if not StructureData.collinear(run,w) or StructureData.high(w)<=StructureData.low(run) or StructureData.low(w)>=StructureData.high(run):
					remaining.append(w); continue
				if StructureData.low(w)<StructureData.low(run):
					var part = StructureData.subrun(w,StructureData.low(w),StructureData.low(run)); part.id=0; remaining.append(part)
				if StructureData.high(w)>StructureData.high(run):
					var part = StructureData.subrun(w,StructureData.high(run),StructureData.high(w)); part.id=0; remaining.append(part)
			stage._walls=remaining
			stage._doors=stage._doors.filter(func(d): return not (StructureData.collinear(run,d) and StructureData.low(run)<=StructureData.low(d) and StructureData.high(run)>=StructureData.high(d)))
		else: stage._walls.append(run)
		stage.normalize_walls()
	elif kind == &"REMOVE_DOOR":
		if stage.get_door(door_id).is_empty(): reason=&"MISSING_DOOR"
		stage._doors=stage._doors.filter(func(d): return d.id!=door_id)
	elif kind in [&"OPEN",&"CLOSE",&"LOCK",&"UNLOCK"]:
		var index=-1
		for i in range(stage._doors.size()):
			if stage._doors[i].id==door_id:index=i;break
		if index<0:reason=&"MISSING_DOOR"
		else:
			var d=stage._doors[index]
			match kind:
				&"OPEN":
					if d.locked:reason=&"LOCKED"
					else:d.state=&"OPEN"
				&"CLOSE":
					if d.state==&"OPEN" and model.occupancy_query.is_valid() and model.occupancy_query.call({"a":Vector2(d.a),"b":Vector2(d.b),"radius":0.05,"id":d.id}):reason=&"OCCUPIED"
					else:d.state=&"CLOSED"
				&"LOCK":
					if d.state==&"OPEN":reason=&"CLOSE_BEFORE_LOCK"
					else:d.locked=true
				&"UNLOCK":d.locked=false
	else: reason=&"UNKNOWN_COMMAND"
	if reason == &"": reason=stage.validate()
	return {"reason":reason,"data":stage}
func execute(model) -> StructureChange:
	var evaluated = evaluate(model)
	var result := StructureChange.new()
	result.actor_id=actor_id
	result.previous_revision=model.structures.revision; result.revision=result.previous_revision
	result.reason=evaluated.reason
	if result.reason != &"": return result
	result.accepted=true
	result.before_state=StructureCodec.encode(model.structures)
	result.after_state=StructureCodec.encode(evaluated.data)
	if result.before_state==result.after_state: return result
	result.topology_changed=kind in [&"WALL",&"DOOR",&"REMOVE_DOOR"]
	result.barrier_changed=result.topology_changed or kind in [&"OPEN",&"CLOSE"]
	result.traversal_changed=true
	result.entity_id=door_id
	if kind==&"DOOR":result.entity_id=evaluated.data._doors[-1].id
	result.old_state=model.structures.get_door(result.entity_id)
	result.new_state=evaluated.data.get_door(result.entity_id)
	classify_change(result)
	model.install_structure(evaluated.data,result)
	return result
static func restore(model,change: StructureChange,undo: bool) -> StructureChange:
	var result := StructureChange.new()
	result.previous_revision=model.structures.revision
	result.revision=model.structures.revision
	var expected: Dictionary = change.after_state if undo else change.before_state
	var current = StructureCodec.encode(model.structures)
	current.erase("next_id"); expected=expected.duplicate(true); expected.erase("next_id")
	if current != expected:
		result.reason=&"STALE_HISTORY"; return result
	var target = StructureCodec.decode(change.before_state if undo else change.after_state)
	if not target.valid: result.reason=target.reason; return result
	target.data.next_id=maxi(target.data.next_id,model.structures.next_id)
	result.accepted=true; result.previous_revision=model.structures.revision
	result.before_state=StructureCodec.encode(model.structures); result.after_state=StructureCodec.encode(target.data)
	result.entity_id=change.entity_id
	result.old_state=model.structures.get_door(result.entity_id)
	result.new_state=target.data.get_door(result.entity_id)
	for d in target.data.get_doors():
		var current_door=model.structures.get_door(d.id)
		if d.state==&"CLOSED" and not current_door.is_empty() and current_door.state==&"OPEN" and model.occupancy_query.is_valid() and model.occupancy_query.call({"a":Vector2(d.a),"b":Vector2(d.b),"radius":0.05,"id":d.id}):
			result.accepted=false;result.reason=&"OCCUPIED";return result
	classify_change(result)
	model.install_structure(target.data,result)
	return result

static func classify_change(change: StructureChange) -> void:
	var before=change.before_state;var after=change.after_state
	var geometry_before=before.doors.map(func(d):return [d.id,d.a,d.b])
	var geometry_after=after.doors.map(func(d):return [d.id,d.a,d.b])
	change.topology_changed=before.walls!=after.walls or geometry_before!=geometry_after
	change.barrier_changed=change.topology_changed or before.doors.map(func(d):return [d.id,d.state])!=after.doors.map(func(d):return [d.id,d.state])
	change.traversal_changed=change.barrier_changed or before.doors!=after.doors
	var points: Array=[]
	for key in ["walls","doors"]:
		for record in before[key]+after[key]:
			if before[key].has(record) and after[key].has(record):continue
			points.append(Vector2(record.a[0],record.a[1]));points.append(Vector2(record.b[0],record.b[1]))
	if not points.is_empty():
		var bounds=Rect2(points[0],Vector2.ZERO)
		for point in points:bounds=bounds.expand(point)
		change.affected_bounds=bounds.grow(.125)
