class_name StructureChange
extends RefCounted
var accepted := false
var reason: StringName = &""
var affected_bounds := Rect2()
var actor_id := 0
var previous_revision := 0
var revision := 0
var topology_changed := false
var barrier_changed := false
var traversal_changed := false
var before_state := {}
var after_state := {}
var entity_id := 0
var old_state := {}
var new_state := {}
