extends SceneTree
## Six hours of synthetic experience: bounded storage and steady update cost.
func _initialize() -> void:
	var memories: Array=[]
	for i in range(12): memories.append(AgentExperienceMemory.new())
	var early: Array[float]=[]; var late: Array[float]=[]
	for step in range(2000):
		var now=step*11.0
		var start=Time.get_ticks_usec()
		for i in range(memories.size()):
			var memory=memories[i]; var point=Vector2((step+i)%200*3,step%13*3)
			memory.visit(point,now,true); memory.sample_body(.1 if step%4==0 else .8,now)
			memory.record(&"meal",point,now,0,step+1,.3,false,.4)
			memory.record(&"received",point,now,(step%100)+1,step+1,.1)
		var elapsed=(Time.get_ticks_usec()-start)/1000.0
		if step>=100 and step<200: early.append(elapsed)
		if step>=1900: late.append(elapsed)
	var largest:=0; var failed:=false
	for memory in memories:
		failed=failed or memory.places.size()>64 or memory.people.size()>24 or memory.habits.size()>16 or memory.episodes.size()>32
		largest=maxi(largest,JSON.stringify(memory.snapshot(22000)).length())
	early.sort(); late.sort()
	print("12 agents / 22000 simulated seconds / 48000 outcomes: bounded=%s" % not failed)
	print("Memory update batch early median %.3f ms / late median %.3f ms / late p95 %.3f ms" % [early[50],late[50],late[95]])
	print("Largest version-1 memory JSON: %d bytes (not runtime heap size)" % largest)
	quit(1 if failed else 0)
