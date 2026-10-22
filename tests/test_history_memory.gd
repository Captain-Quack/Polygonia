extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var script = load("res://agents/memory/experience_memory.gd")
	if script == null: quit(1); return
	var m = script.new()
	m.record(&"attacked",Vector2(1,1),1.0,7)
	var initial = m.person(7,1).harm
	for i in range(20): m.record(&"attacked",Vector2(1,1),1.0+i*.1,7)
	check(m.episodes.size()==1 and is_equal_approx(m.person(7,3).harm,initial*exp(-2.0/900.0)),"one continuous encounter is one piece of evidence")
	check(m.place(Vector2(1.5,1.5),3).danger > 0,"nearby points share a remembered patch")
	check(m.place(Vector2(-1,-1),3).danger==0,"negative and positive exterior patches remain distinct")
	var witnessed = script.new(); witnessed.record(&"attacked",Vector2(1,1),1,7,0,1,true)
	check(witnessed.person(7,1).harm < initial,"witnessed harm has less evidential weight")
	var meals=script.new()
	meals.record(&"meal",Vector2.ZERO,1,0,1,.1,false,.8)
	meals.record(&"meal",Vector2.ZERO,3,0,1,.8,false,.8)
	check(meals.episodes.size()==2 and meals.habit(&"eat",Vector2.ZERO,3).success>.7,"separately completed meals teach separate outcomes even at the same source")
	for i in range(60): m.visit(Vector2(1,1),20+i,true)
	check(m.place(Vector2(1,1),80).danger < .05,"sustained safe revisits revise fear")
	var familiarity = m.place(Vector2(1,1),80).familiarity
	for i in range(20): m.visit(Vector2(1,1),80+i*.01,true)
	check(m.place(Vector2(1,1),80.2).familiarity <= familiarity+.051,"familiarity is not accumulated per frame")
	for i in range(200):
		m.record(&"meal",Vector2(i*3,1),100+i*11,0,i,.3,false,.3)
		m.record(&"received",Vector2(i*3,1),100+i*11,i+1,i)
	check(m.places.size()<=64 and m.people.size()<=24 and m.habits.size()<=16 and m.episodes.size()<=32,"all memory stores remain bounded")
	var data = JSON.parse_string(JSON.stringify(m.snapshot(2300)))
	var copy = script.new()
	check(copy.restore(data,5000),"JSON-safe snapshots restore")
	check(is_equal_approx(m.place(Vector2(597,1),2300).food,copy.place(Vector2(597,1),5000).food),"clock rebasing preserves evidence age")
	check(copy.episodes.size()==m.episodes.size(),"episodes survive codec")
	var before = JSON.stringify(copy.snapshot(5000))
	data.version = 999
	check(not copy.restore(data,5000) and before==JSON.stringify(copy.snapshot(5000)),"invalid version rejects atomically")
	data = m.snapshot(2300); data.places[0].food = NAN
	check(not copy.restore(data,5000),"nonfinite evidence rejects")
	data = m.snapshot(2300); data.people[0].id = -1
	check(not copy.restore(data,5000),"invalid identities reject")
	print("history_memory: %d failures" % failures); quit(1 if failures else 0)
