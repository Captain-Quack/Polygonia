class_name PolygonAgent
extends RefCounted
var id := 0
var position := Vector2.ZERO
var facing := 0.0
var radius := 0.2
var speed := 1.4
var sight_range := 6.0
var body := PolygonBody.new()
## Value snapshots, never references to mutable world-object state.
var beliefs: Dictionary = {}
var recent_events: Array[String] = []
var action: StringName = &"idle"
var controller: AgentActionController
var decision_scores: Array = []
var next_decision := 0.0
var next_perception := 0.0
var exploration_index := 0
func remember_event(message: String) -> void:
	if not recent_events.is_empty() and recent_events[-1] == message: return
	recent_events.append(message)
	if recent_events.size() > 8: recent_events.pop_front()
