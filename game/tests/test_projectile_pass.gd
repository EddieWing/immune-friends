extends SceneTree
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=load("res://scripts/simulation.gd").new()
	s.reset(98,12);s.cells.clear();s.viruses.resize(80)
	for i in range(80):s.viruses[i]={}
	var tag={"kind":"tag","life":1.0}
	s.particles=[tag.duplicate(),tag.duplicate()]
	check(not s.dense_projectile_queries(),"sparse queries retain scalar path")
	for i in range(22):s.particles.append(tag.duplicate())
	check(s.dense_projectile_queries(),"dense tag queries can use browser batch")
	for p in s.particles:p.life=0.0
	check(not s.dense_projectile_queries(),"dead tags never trigger batch")
	for p in s.particles:p.life=1.0;p.kind="bullet"
	check(not s.dense_projectile_queries(),"bullet-only fields retain scalar path")
	var result=load("res://tests/fixtures/projectile_pass_comparison.gd").new().run()
	check(result.passed,"240 full steps equal scalar implementation")
	if OS.has_feature("web"):
		var cases=load("res://tests/fixtures/projectile_pass_cases.gd").new().run()
		check(cases.passed,"288 ordered projectile passes preserve hits and recipes")
		print("PROJECTILE_CASES ",JSON.stringify(cases))
	else:print("SKIP: browser kernel requires Web; native fallback covered above")
	print("PROJECTILE_PASS_TEST failures=",errors)
	quit(errors)
