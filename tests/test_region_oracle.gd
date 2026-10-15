extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func blocked(a: Vector2i,b: Vector2i,walls: Array) -> bool:
	var midpoint=(Vector2(a)+Vector2(b))*.5+Vector2.ONE*.5
	for w in walls:
		if a.x!=b.x and w.a.x==w.b.x and midpoint.x==w.a.x and midpoint.y>w.a.y and midpoint.y<w.b.y:return true
		if a.y!=b.y and w.a.y==w.b.y and midpoint.y==w.a.y and midpoint.x>w.a.x and midpoint.x<w.b.x:return true
	return false
func _initialize() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=71349
	for experiment in range(20):
		var model=WorldModel.new()
		for i in range(35):
			var a=Vector2i(rng.randi_range(0,6),rng.randi_range(0,6))
			var b=Vector2i(rng.randi_range(0,6),a.y) if i%2 else Vector2i(a.x,rng.randi_range(0,6))
			if a!=b:model.execute(StructureCommand.wall(a,b,false))
		var walls=model.structures.get_walls()
		var components: Dictionary={};var number=0
		var region_for_component: Dictionary={};var component_for_region: Dictionary={}
		for y in range(-1,7):
			for x in range(-1,7):
				var start=Vector2i(x,y)
				if components.has(start):continue
				number+=1;var queue: Array=[start];components[start]=number;var cursor=0
				while cursor<queue.size():
					var a=queue[cursor];cursor+=1
					for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						var b=a+direction
						if b.x< -1 or b.y< -1 or b.x>6 or b.y>6 or components.has(b) or blocked(a,b,walls):continue
						components[b]=number;queue.append(b)
		for p in components:
			var component=components[p]
			var id=model.regions.locate(Vector2(p)+Vector2.ONE*.5).region_id
			if region_for_component.has(component):check(region_for_component[component]==id,"one flood component maps to one geometric region")
			if component_for_region.has(id):check(component_for_region[id]==component,"distinct flood components remain distinct geometric regions")
			region_for_component[component]=id;component_for_region[id]=component
		for r in model.regions.get_regions():
			if not r.bounded:continue
			var count=0
			for p in components:
				if region_for_component[components[p]]==r.id:count+=1
			check(r.area==count,"bounded region area agrees with independent raster oracle")
		model.free()
	print("region_oracle: %d failures"%failures);quit(1 if failures else 0)
