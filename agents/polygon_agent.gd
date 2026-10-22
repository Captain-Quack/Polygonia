class_name PolygonAgent
extends RefCounted
var id := 0
var position := Vector2.ZERO
var facing := 0.0
var radius := 0.2
var speed := 1.4
var sight_range := 6.0
var body := PolygonBody.new()
var motion := AgentMotion.new()
## Value snapshots, never references to mutable world-object state.
var beliefs: Dictionary = {}
var recent_events: Array[String] = []
var action: StringName = &"idle"
var controller: AgentActionController
var decision_scores: Array = []
var next_decision := 0.0
var next_perception := 0.0
var exploration := AgentExploration.new()
func remember_event(message: String) -> void:
	if not recent_events.is_empty() and recent_events[-1] == message: return
	recent_events.append(message)
	if recent_events.size() > 8: recent_events.pop_front()

var next_food_share := 0.0
var food_gesture_until := 0.0

var personality := AgentPersonality.new()
var assessment: Dictionary = {}
var decision_reason := "Observing the world."
func effective_speed() -> float:
	return speed*(1.0-body.fatigue*.35)*float(assessment.get("mobility",1.0))

var route_cursor := 0
var timely_food := false
var ordinary_food_unchecked := false

var familiarity: Dictionary = {}
var memory := AgentExperienceMemory.new()
var next_cognition := 0.0
func consideration_limit() -> int:
	return maxi(2,8-int(body.deprivation*6))

var agent_beliefs: Dictionary = {}
var threats: Dictionary = {}
var prey_retry: Dictionary = {}

var death_handled := false
var corpse_id := 0

func inspection_text() -> String:
	return "Polygon %d · %s\nHunger %d%% · Fatigue %d%% · Health %d%%\nUrgency %d%% · Deprivation %d%% · Impairment %d%%\nDesperation %d%% · Constraints %d%%\nKindness %d%%\nTarget: %s\n%s" % [id,str(action).capitalize(),roundi(body.hunger()*100),roundi(body.fatigue*100),roundi(body.health*100),roundi(float(assessment.get("urgency",0))*100),roundi(body.deprivation*100),roundi(float(assessment.get("impairment",0))*100),roundi(desperation*100),roundi(constraint_pressure*100),roundi(personality.kindness*100),str(controller.current.get("key","none")),decision_reason]

## Frustrated access and resulting motivation are separate from physical impairment.
var constraint_pressure := 0.0
var desperation := 0.0
var last_setback_at := -INF
func report_setback(now: float) -> void:
	last_setback_at = now

