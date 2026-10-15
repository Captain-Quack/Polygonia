class_name StructureCommand
extends RefCounted
var kind: StringName
var a = Vector2i.ZERO
var b = Vector2i.ZERO
var erase := false
var door_id := 0
var actor_id := 0
var radius:=0.0
var segments:=64
var circle_id:=0
var offset:=0.0
var arc_width:=0.0
static func wall(start,end,remove: bool) -> StructureCommand:
	var c := StructureCommand.new(); c.kind = &"WALL"; c.a=StructureData.coordinate(Vector2(start)); c.b=StructureData.coordinate(Vector2(end)); c.erase=remove; return c
static func place_door(start,end) -> StructureCommand:
	var c := wall(start,end,false); c.kind = &"DOOR"; return c
static func remove_door(id: int) -> StructureCommand:
	var c := StructureCommand.new(); c.kind = &"REMOVE_DOOR"; c.door_id=id; return c
static func door_action(id: int,action: StringName,actor: int=0) -> StructureCommand:
	var c := StructureCommand.new();c.kind=action;c.door_id=id;c.actor_id=actor;return c
static func circle(center: Vector2i,size: float,count: int,remove: bool=false) -> StructureCommand:
	var c:=StructureCommand.new();c.kind=&"CIRCLE";c.a=center;c.radius=size;c.segments=count;c.erase=remove;return c
static func arc(center: Vector2i,size: float,count: int,start: float,width: float,remove: bool=false) -> StructureCommand:
	var c=circle(center,size,count,remove);c.kind=&"ARC";c.offset=start;c.arc_width=width;return c
static func circle_door(host_id: int,start: float) -> StructureCommand:
	var c:=StructureCommand.new();c.kind=&"CIRCLE_DOOR";c.circle_id=host_id;c.offset=start;return c
func evaluate(model) -> Dictionary:
	var stage: StructureData = model.structures.copy()
	var reason: StringName = &""
	if kind in [&"CIRCLE",&"ARC"]:
		if not is_finite(radius) or radius<1 or radius!=floorf(radius) or segments<64 or segments>512 or segments%4!=0:return {"reason":&"INVALID_CIRCLE","data":stage}
		var index=-1
		for i in range(stage._circles.size()):
			if stage._circles[i].center==a and stage._circles[i].radius==radius:index=i;break
		var source={"id":0,"center":a,"radius":radius,"segments":segments} if index<0 else stage._circles[index]
		var total=CircleBoundary.length(stage.circle_points(source),true)
		var width=total if kind==&"CIRCLE" else arc_width
		if not is_finite(offset) or not is_finite(width) or width<=ArcIntervals.EPS or width>total+ArcIntervals.EPS:return {"reason":&"INVALID_ARC","data":stage}
		var cut=ArcIntervals.wrapped(offset,width,total)
		var before: Array=[] if index<0 else stage.circle_ranges(source)
		var after=ArcIntervals.subtract(before,cut) if erase else ArcIntervals.merge(before+cut)
		if after==before:return {"reason":&"","data":stage}
		if index<0:source.id=stage.allocate_id()
		var retained: Array=[]
		for d in stage._doors:
			if d.get("circle_id",0)!=source.id:retained.append(d);continue
			var supported=ArcIntervals.overlap(after,ArcIntervals.wrapped(d.offset,1.0,total))
			if supported>=1.0-ArcIntervals.EPS:retained.append(d)
			elif supported>ArcIntervals.EPS:return {"reason":&"PARTIAL_DOOR_SUPPORT","data":stage}
		stage._doors=retained
		if after.is_empty():stage._circles.remove_at(index)
		else:
			if after.size()==1 and after[0][0]==0 and absf(after[0][1]-total)<ArcIntervals.EPS:source.erase("ranges")
			else:source.ranges=after
			if index<0:stage._circles.append(source)
			else:stage._circles[index]=source
	elif kind==&"CIRCLE_DOOR":
		stage._doors.append({"id":stage.allocate_id(),"a":Vector2.ZERO,"b":Vector2.ZERO,"circle_id":circle_id,"offset":offset,"state":&"CLOSED","locked":false})
	elif kind in [&"WALL",&"DOOR"]:
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
			stage._doors=stage._doors.filter(func(d): return d.has("circle_id") or not (StructureData.collinear(run,d) and StructureData.low(run)<=StructureData.low(d) and StructureData.high(run)>=StructureData.high(d)))
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
					if d.state==&"OPEN" and model.occupancy_query.is_valid() and model.occupancy_query.call({"a":Vector2(stage.get_door(d.id).a),"b":Vector2(stage.get_door(d.id).b),"radius":0.05,"id":d.id,"path":StructureData.door_path(stage.get_door(d.id))}):reason=&"OCCUPIED"
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
	if kind in [&"DOOR",&"CIRCLE_DOOR"]:result.entity_id=evaluated.data._doors[-1].id
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
		if d.state==&"CLOSED" and not current_door.is_empty() and current_door.state==&"OPEN" and model.occupancy_query.is_valid() and model.occupancy_query.call({"a":Vector2(d.a),"b":Vector2(d.b),"radius":0.05,"id":d.id,"path":StructureData.door_path(d)}):
			result.accepted=false;result.reason=&"OCCUPIED";return result
	classify_change(result)
	model.install_structure(target.data,result)
	return result

static func classify_change(change: StructureChange) -> void:
	var before=change.before_state;var after=change.after_state
	var geometry_before=before.doors.map(func(d):return [d.id,d.get("a"),d.get("b"),d.get("circle_id"),d.get("offset")])
	var geometry_after=after.doors.map(func(d):return [d.id,d.get("a"),d.get("b"),d.get("circle_id"),d.get("offset")])
	change.topology_changed=before.walls!=after.walls or before.get("circles",[])!=after.get("circles",[]) or geometry_before!=geometry_after
	change.barrier_changed=change.topology_changed or before.doors.map(func(d):return [d.id,d.state])!=after.doors.map(func(d):return [d.id,d.state])
	change.traversal_changed=change.barrier_changed or before.doors!=after.doors
	var points: Array=[]
	for key in ["walls","doors"]:
		for record in before[key]+after[key]:
			if before[key].has(record) and after[key].has(record):continue
			if record.has("a"):
				points.append(Vector2(record.a[0],record.a[1]));points.append(Vector2(record.b[0],record.b[1]))
	# Circle bounds also cover any of their derived door paths.
	if before.get("circles",[])!=after.get("circles",[]) or before.doors!=after.doors:
		for c in before.get("circles",[])+after.get("circles",[]):
			points.append(Vector2(c.center[0],c.center[1])-Vector2.ONE*c.radius)
			points.append(Vector2(c.center[0],c.center[1])+Vector2.ONE*c.radius)
	if not points.is_empty():
		var bounds=Rect2(points[0],Vector2.ZERO)
		for point in points:bounds=bounds.expand(point)
		change.affected_bounds=bounds.grow(.125)
