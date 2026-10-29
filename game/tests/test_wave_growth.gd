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
	var rng=RandomNumberGenerator.new();rng.seed=42
	var queue=plan.schedule(old.wave,old.emitters,rng)
	check(queue.size()==102,"MC-033: complete final wave release queue")
	var exact=true
	for i in range(old.emitters.size()):
		var emitter=old.emitters[i]
		var entries=queue.filter(func(e):return e.emitter==i)
		exact=exact and entries.size()==emitter.amount
		for j in range(entries.size()):exact=exact and entries[j].p==emitter.p and is_equal_approx(entries[j].due,emitter.delay+j*emitter.cooldown)
	check(exact,"MC-033: every source keeps position, delay and independent interval")
	var sim=preload("res://scripts/simulation.gd").new();sim.reset(42,12);sim.begin_battle()
	sim.spawn_queue=[{"type":"basic","lane":0,"p":Vector2(3000,0),"due":1.0},{"type":"basic","lane":0,"p":Vector2(3000,0),"due":5.0}]
	sim.elapsed=1;sim.advance_spawns(0);sim.damage_virus(sim.viruses[0],999)
	for i in range(60):sim.update(1.0/60)
	check(sim.phase=="battle" and sim.spawn_queue.size()==1,"MC-033: early kill cannot cancel future release")
	sim.elapsed=5;sim.advance_spawns(0)
	check(sim.viruses.any(func(v):return v.alive),"MC-033: later source releases after empty battlefield")
	quit(errors)
