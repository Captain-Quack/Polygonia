class_name AgentPersonality
extends RefCounted
var caution := 0.5
var persistence := 0.5
var aggression := 0.5
var kindness := 0.5
static func from_seed(simulation_seed: int,agent_id: int) -> AgentPersonality:
	var rng = RandomNumberGenerator.new()
	rng.seed = simulation_seed + agent_id * 104729
	var result = AgentPersonality.new()
	result.caution = rng.randf(); result.persistence = rng.randf(); result.aggression = rng.randf()
	result.kindness = rng.randf()
	return result

