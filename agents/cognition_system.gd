class_name AgentCognition
extends RefCounted
## Connect personal evidence to the existing decision pipeline, never world effects.
static func observe(agent: PolygonAgent,simulation: AgentSimulation) -> void:
	var now = simulation.time
	agent.memory.time = now
	if now<agent.next_cognition: return
	agent.next_cognition = now+1.0
	var safe := true
	for threat in agent.threats.values():
		if threat.until>now: safe=false; break
	if safe:
		for event in agent.memory.episodes:
			if event.kind==&"attacked" and now-event.at<2 and AgentExperienceMemory.cell(event.position)==AgentExperienceMemory.cell(agent.position): safe=false; break
	agent.memory.visit(agent.position,now,safe)
	agent.memory.sample_body(agent.body.nourishment,now)
	# Empty patches disconfirm an old food expectation only after inspecting the patch.
	var c = AgentExperienceMemory.cell(agent.position)
	var center = (Vector2(c)+Vector2.ONE*.5)*AgentExperienceMemory.PLACE_SIZE
	if agent.position.distance_to(center)>.8 or agent.memory.place(center,now).food<.1: return
	for b in agent.beliefs.values():
		if b.interaction==&"eat" and b.available and AgentExperienceMemory.cell(b.position)==c: return
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		if not AgentPerception.visible(agent,center+corner,simulation.model): return
	agent.memory.record(&"missing",center,now)
static func outcome(agent: PolygonAgent,option: Dictionary,effects: Dictionary,now: float) -> void:
	var eating = option.interaction==&"eat"
	var dimension: StringName = &"nourishment" if eating else &"fatigue"
	var amount = absf(float(effects.get(dimension,0)))
	var expected = absf(float(option.get("expected_effects",option.effects).get(dimension,0)))
	agent.memory.record(&"meal" if eating else &"rested",option.position,now,0,option.source,amount,false,expected)
static func social_risks(agent: PolygonAgent,now: float) -> Array:
	var result: Array=[]
	for id in agent.memory.people:
		var observed: Dictionary=agent.agent_beliefs.get(id,{})
		if observed.is_empty() or now-float(observed.observed_at)>3: continue
		var harm=float(agent.memory.person(id,now).harm)
		if harm>.1: result.append({"id":id,"position":observed.position,"harm":harm})
	result.sort_custom(func(a,b): return a.harm>b.harm)
	return result.slice(0,4)
static func adjust(agent: PolygonAgent,option: Dictionary,now: float,social_evidence: Array = []) -> void:
	var p = agent.memory.place(option.position,now)
	var h = agent.memory.habit(option.interaction,option.position,now)
	var success = p.food if option.interaction==&"eat" else p.rest
	var risk = p.danger*(.55+.35*agent.personality.caution)*(1-.7*agent.desperation)
	var social_risk:=0.0; var feared_id:=0
	for person in social_evidence:
		var proximity=maxf(0,1-option.position.distance_to(person.position)/3.0)
		if person.harm*proximity>social_risk: social_risk=person.harm*proximity; feared_id=person.id
	risk+=social_risk*.5*(1-.7*agent.desperation)
	var familiar = p.familiarity*(.08+.12*agent.personality.persistence+.15*agent.body.deprivation)
	var benefit = .3*success+.15*(h.success-.5)+.2*h.error*h.confidence+.1*p.access+familiar
	option.score *= clampf(1+benefit-risk,.2,1.6)
	option.memory_reason = ""
	if social_risk>.2: option.memory_reason="Remembered harm makes approaching Polygon %d less attractive." % feared_id
	elif risk>.1: option.memory_reason="Remembered danger makes this place less attractive."
	elif success>.1: option.memory_reason="Remembered success makes this place worth returning to."
	elif familiar>.04: option.memory_reason="Experience makes this place familiar."
	elif h.confidence>.1: option.memory_reason="Previous outcomes influence this choice."
static func path_risk(agent: PolygonAgent,points: Array,now: float) -> float:
	if points.is_empty() or agent.memory.places.is_empty(): return 0.0
	var distance=_distance(agent.position,points)
	var before=agent.position; var segment:=0; var passed:=0.0; var total:=0.0
	# Sixteen samples across the entire polyline, independent of lattice waypoint count.
	for i in range(1,17):
		var target=distance*float(i)/16.0
		while segment<points.size()-1 and passed+before.distance_to(points[segment])<target:
			passed+=before.distance_to(points[segment]); before=points[segment]; segment+=1
		var point=before.move_toward(points[segment],maxf(0,target-passed))
		var known: Dictionary=agent.memory.places.get(AgentExperienceMemory.cell(point),{})
		if not known.is_empty(): total+=float(known.danger)*exp(-maxf(0,now-float(known.at))/900.0)
	return total/16.0
static func route(agent: PolygonAgent,option: Dictionary,simulation: AgentSimulation) -> Dictionary:
	var control = agent.controller
	var result: Dictionary
	if control.current.get("key","")==option.key and control.current.get("position")==option.position and control.route_revision==simulation.model.structures.traversal_revision and not control.route_points.is_empty():
		result={"status":&"OK","points":control.route_points.duplicate()}
	else: result=simulation.navigation.route(agent.position,option.position,agent.radius)
	if result.status!=&"OK": return result
	var risk = path_risk(agent,result.points,simulation.time)
	result.risk=risk
	if risk<.15 or agent.desperation>.7: return result
	var best_cost = _distance(agent.position,result.points)+risk*12*(.5+agent.personality.caution)
	var candidates: Array = []
	for raw in agent.memory.places.values():
		var point=(Vector2(raw.cell)+Vector2.ONE*.5)*AgentExperienceMemory.PLACE_SIZE
		var known=agent.memory.place(point,simulation.time)
		if known.familiarity<.1 or known.danger>.1 or point.distance_to(agent.position)<.5: continue
		candidates.append({"point":point,"distance":agent.position.distance_to(point)+point.distance_to(option.position)})
	candidates.sort_custom(func(a,b): return a.distance<b.distance)
	# Only one remembered waypoint is probed, never a personalized whole-world path grid.
	for candidate in candidates.slice(0,1):
		var first=simulation.navigation.route(agent.position,candidate.point,agent.radius)
		if first.status!=&"OK": continue
		var second=simulation.navigation.route(candidate.point,option.position,agent.radius)
		if second.status!=&"OK": continue
		var points: Array=first.points+second.points
		var alternative_risk=path_risk(agent,points,simulation.time)
		var cost=_distance(agent.position,points)+alternative_risk*12*(.5+agent.personality.caution)
		if cost<best_cost:
			result={"status":&"OK","points":points,"risk":alternative_risk,"detour":true}; best_cost=cost
	return result
static func _distance(origin: Vector2,points: Array) -> float:
	var distance:=0.0
	for p in points: distance+=origin.distance_to(p); origin=p
	return distance
static func recalled_destinations(agent: PolygonAgent) -> Array:
	var results: Array=[]
	for raw in agent.memory.places.values():
		var point=(Vector2(raw.cell)+Vector2.ONE*.5)*AgentExperienceMemory.PLACE_SIZE
		var p=agent.memory.place(point,agent.memory.time)
		if agent.position.distance_to(point)<1.0 or p.access<-.5: continue
		var usefulness=p.food*agent.body.hunger()+p.rest*agent.body.fatigue
		var score=usefulness-.5*p.danger-.015*agent.position.distance_to(point)
		if score>.05: results.append({"point":point,"score":score})
	results.sort_custom(func(a,b): return a.score>b.score)
	return results.slice(0,2)
static func willingness(donor: PolygonAgent,recipient_id: int,now: float) -> float:
	if donor.personality.kindness<=0: return 0
	var p=donor.memory.person(recipient_id,now)
	return donor.personality.kindness+.2*p.help-.65*p.harm-.2*donor.memory.scarcity
static func witnessed_attack(simulation: AgentSimulation,actor: PolygonAgent,target: PolygonAgent,amount: float) -> void:
	target.memory.record(&"attacked",target.position,simulation.time,actor.id,0,amount)
	for witness in simulation.possible_witnesses(target.position):
		if witness==actor or witness==target or not witness.body.alive(): continue
		if AgentPerception.visible(witness,target.position,simulation.model) and AgentPerception.visible(witness,actor.position,simulation.model):
			witness.memory.record(&"attacked",target.position,simulation.time,actor.id,0,amount,true)
			witness.next_decision=minf(witness.next_decision,simulation.time)
static func inspection(agent: PolygonAgent,now: float) -> String:
	var p=agent.memory.place(agent.position,now)
	var text="\nExperience: %d places · %d individuals · %d episodes\nHere: familiarity %d%% · expected danger %d%%\nExpected scarcity %d%%" % [agent.memory.places.size(),agent.memory.people.size(),agent.memory.episodes.size(),roundi(p.familiarity*100),roundi(p.danger*100),roundi(agent.memory.scarcity*100)]
	var recent=agent.memory.episodes.slice(-3)
	for e in recent:
		var description: String={&"meal":"Completed a meal",&"rested":"Recovered by resting",&"attacked":"Witnessed an attack" if e.witnessed else "Was attacked",&"received":"Received shared food",&"gave":"Shared food",&"missing":"Found a remembered place empty",&"blocked":"Encountered blocked access",&"interrupted":"An interaction was interrupted",&"escaped":"Completed an escape"}.get(e.kind,str(e.kind))
		text+="\n%s%s (%ds ago)" % [description," — Polygon %d" % e.actor if e.actor>0 else "",roundi(maxf(0,now-e.at))]
	return text
