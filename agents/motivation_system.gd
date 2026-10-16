class_name AgentMotivation
extends RefCounted
static func weights(agent: PolygonAgent) -> Dictionary:
	var urgency = float(agent.assessment.get("urgency",0))
	var harm = float(agent.assessment.get("harm_rate",0))
	return {"food":1+urgency*8,"search":1+urgency*16,"danger":harm>0 and urgency>0,"urgency":urgency}
