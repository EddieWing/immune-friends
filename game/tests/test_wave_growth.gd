extends SceneTree
const Plan=preload("res://scripts/infection_plan.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var plan=Plan.new();var kinds=["basic","wave","jumper","seeker","splitter"]
	var old={};var expected=0
	for round_no in range(1,13):
		var current=plan.build(42,round_no,kinds);expected+=plan.GROWTH[round_no-1]
		var total=0
		for group in current.wave:total+=group.count
		check(total==expected and current.wave.size()==ceili(round_no/2.0),"MC-032: cumulative groups and count round %d"%round_no)
		if not old.is_empty():
			check(current.emitters.size()>=old.emitters.size(),"MC-032: growth never removes emitters")
		check(current.wave.all(func(g):return g.type!="splitter"),"MC-032: excluded type cannot be rolled")
		old=current
	check(plan.build(42,3,kinds,0).wave[1].type=="basic","MC-032: NewPlayer second group remains Basic")
	check(plan.build(42,3,kinds,3).wave[1].type!="basic","MC-032: trained second group introduces another type")
	check(old==plan.build(42,12,kinds),"MC-032: preview rebuild is deterministic")
	quit(errors)
