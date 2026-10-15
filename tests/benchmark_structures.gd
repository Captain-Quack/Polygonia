extends SceneTree
## Optional observational benchmark; timings are not assertions.
func _initialize() -> void:
	for count in [100,500,1000]:
		var model=load("res://world/world_model.gd").new()
		var walls: Array=[]
		for i in range(count/4):
			var x=i*4
			for segment in [[[x,0],[x+2,0]],[[x+2,0],[x+2,2]],[[x,2],[x+2,2]],[[x,0],[x,2]]]:
				walls.append({"id":walls.size()+1,"a":segment[0],"b":segment[1],"material":"solid"})
		var start=Time.get_ticks_usec()
		var change=model.replace_structures({"version":1,"next_id":count+1,"walls":walls,"doors":[]})
		var elapsed=(Time.get_ticks_usec()-start)/1000.0
		assert(change.accepted)
		assert(model.regions.get_regions().size()==count/4+1)
		print("%d wall runs: %.2f ms validated replacement + region rebuild; %d bounded regions"%[count,elapsed,count/4])
		model.free()
	quit()
