class_name AgentFoodSocial
extends RefCounted
## Food sharing and contests use observed claims; the existing controller owns meals and combat.
static func desperate(agent: PolygonAgent,profile: EmergencyProfile) -> bool:
	return agent.body.nourishment < profile.predation_nourishment and (agent.body.deprivation >= profile.predation_deprivation or agent.desperation >= profile.desperate_feeding_threshold)

static func share(simulation: AgentSimulation) -> void:
	for donor in simulation.agents:
		var control = donor.controller
		if not donor.body.alive() or donor.personality.kindness <= 0 or donor.body.nourishment < .25 or donor.desperation >= .65: continue
		if not donor.threats.is_empty() or simulation.time < donor.next_food_share: continue
		if control.current.get("kind") != &"interact" or not control.provider is FoodInteractionProvider: continue
		var provider = control.provider as FoodInteractionProvider
		if provider.portion_count() < 2 or not provider.has_user(donor.id): continue
		var retained_nourishment=float(provider.meal_effects().get(&"nourishment",0))*(provider.portion_count()-1.0)/provider.portion_count()
		if donor.body.nourishment+retained_nourishment < .25+.2*donor.memory.scarcity: continue
		var source = simulation.objects.get_object(control.current.source)
		if source == null or donor.position.distance_to(source.position) > .25: continue
		var recipient: PolygonAgent
		var greatest_need := .4
		for id in donor.agent_beliefs:
			var observed: Dictionary = donor.agent_beliefs[id]
			if observed.observed_at != simulation.time or donor.position.distance_to(observed.position) > donor.radius+float(observed.radius)+simulation._profile.contact_margin: continue
			var other = simulation.get_agent(id)
			if other == null or not other.body.alive() or other.controller.provider != null or not other.threats.is_empty(): continue
			if not AgentPerception.visible(other,source.position,simulation.model): continue
			# Hunger is coarse visible distress, like the existing condition snapshot.
			var need: float = observed.hunger
			if AgentCognition.willingness(donor,id,simulation.time)<.6: continue
			var history=donor.memory.person(id,simulation.time)
			need += .12*history.help-.2*history.harm
			if need > greatest_need: recipient = other; greatest_need = need
		if recipient == null: continue
		var portion = simulation.objects.share_food(source.id,donor.id,recipient.id,recipient.position)
		if portion == null: continue
		adopt(recipient,portion,simulation,"Received a shared circle of food.")
		donor.next_food_share = simulation.time+.5
		donor.food_gesture_until = simulation.time+.5
		donor.remember_event("Shared a circle of food with Polygon %d." % recipient.id)
		recipient.remember_event("Polygon %d shared food with me." % donor.id)
		donor.memory.record(&"gave",donor.position,simulation.time,recipient.id,portion.id)
		recipient.memory.record(&"received",recipient.position,simulation.time,donor.id,portion.id)
		# The donor's remaining expected effects changed, but its meal progress did not.
		control.current.expected_effects=provider.meal_effects()
		AgentPerception.observe(donor,simulation.objects,simulation.model,simulation.time)

static func adopt(agent: PolygonAgent,object: PolygonWorldObject,simulation: AgentSimulation,reason: String) -> void:
	var control = agent.controller
	control.cancel(agent)
	var provider = object.providers[0]
	if not provider.begin(agent.id): return
	AgentPerception.observe(agent,simulation.objects,simulation.model,simulation.time)
	var key = "%d:0" % object.id
	control.current = agent.beliefs[key].duplicate(true)
	control.current.merge({"kind":&"interact","score":120.0,"reason":reason},true)
	control.provider = provider
	control.route_revision = simulation.model.structures.traversal_revision
	agent.action = &"eating"
	agent.decision_reason = reason
	agent.next_decision = simulation.time
	agent.remember_event(reason)

static func candidates(agent: PolygonAgent,simulation: AgentSimulation) -> Array:
	var options: Array = []
	if not agent.threats.is_empty() or not desperate(agent,simulation._profile) or agent.personality.aggression <= 0 or agent.timely_food or agent.ordinary_food_unchecked or agent.controller.provider != null: return options
	var considered := 0
	for key in agent.beliefs:
		var belief: Dictionary = agent.beliefs[key]
		if not belief.get("divisible_food",false) or belief.observed_at != simulation.time or belief.available or belief.get("holders",[]).is_empty(): continue
		if simulation.time < belief.retry_at and belief.failed_revision == simulation.model.structures.traversal_revision: continue
		var owner: int = belief.holders[0]
		var observed: Dictionary = agent.agent_beliefs.get(owner,{})
		if owner == agent.id or observed.is_empty() or observed.observed_at != simulation.time: continue
		if considered >= 4: break
		considered += 1
		var route = simulation.navigation.route(agent.position,belief.position,agent.radius)
		if route.status==&"DEFERRED": continue
		if route.status != &"OK":
			belief.retry_at = simulation.time+3; belief.failed_revision = simulation.model.structures.traversal_revision
			agent.report_setback(simulation.time); continue
		var score = 125+20*agent.personality.aggression+20*agent.desperation-30*agent.personality.caution*float(observed.condition)-agent.position.distance_to(belief.position)*2
		options.append({"kind":&"contest_food","key":"contest:"+key,"food_key":key,"source":belief.source,"revision":belief.revision,"target":owner,"position":belief.position,"route_points":route.points,"route_revision":simulation.model.structures.traversal_revision,"score":score,"reason":"Desperate for food: challenging its holder.","urgent":true})
	return options

static func tick_contest(agent: PolygonAgent,simulation: AgentSimulation,delta: float) -> void:
	var control = agent.controller
	var current = control.current
	var object = simulation.objects.get_object(current.source)
	# Never inspect an unseen current claim, position, or stock to guide pursuit.
	if object == null or not AgentPerception.visible(agent,current.position,simulation.model):
		control.cancel(agent); return
	if object.position != current.position or object.revision != current.revision:
		control.cancel(agent); return
	var provider = object.providers[0] as FoodInteractionProvider
	if provider == null or provider.portion_count() == 0 or not desperate(agent,simulation._profile):
		control.cancel(agent); return
	if provider.available():
		if agent.position.distance_to(object.position) <= .25:
			adopt(agent,object,simulation,"Took food after its holder gave way.")
			return
	else:
		var owner = simulation.get_agent(current.target)
		if owner == null or not provider.has_user(owner.id) or not AgentPerception.visible(agent,owner.position,simulation.model):
			control.cancel(agent); return
		var contact = agent.radius+owner.radius+simulation._profile.contact_margin
		if agent.position.distance_to(owner.position) <= contact:
			agent.action = &"contesting food"
			simulation.combat.queue_strike(agent.id,owner.id,false)
			return
	# Rebuild only after geometry changes; food positions are otherwise immutable.
	if control.route_revision != simulation.model.structures.traversal_revision or control.route_points.is_empty():
		var route = simulation.navigation.route(agent.position,object.position,agent.radius)
		if route.status==&"DEFERRED": agent.action=&"waiting: route assessment"; return
		if route.status != &"OK": control.cancel(agent); agent.report_setback(simulation.time); return
		control.route_points = route.points; control.route_revision = simulation.model.structures.traversal_revision
	agent.action = &"challenging for food"
	if not control._move(agent,simulation.navigation,delta): control.cancel(agent)
