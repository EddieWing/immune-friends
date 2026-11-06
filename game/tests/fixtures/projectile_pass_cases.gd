extends RefCounted
const Sim=preload("res://scripts/simulation.gd")
const Old=preload("res://tests/fixtures/native_projectiles.gd")
func native_pass(s,delta,movement):
	s.advance_projectiles_native(delta,movement)
func build(old,trial):
	var s=Old.new() if old else Sim.new()
	s.reset(814+trial,12);s.gym_mode=true;s.experimental=trial%3!=0;s.cells.clear();s.viruses.clear();s.particles.clear()
	var rng=RandomNumberGenerator.new();rng.seed=trial+947
	for i in range(8):
		var c=s.make_cell(["bullet_wall","tag_splitter","mortar","seeker_factory","wall","cannon","tag_splitter","gatling"][i],Vector2(rng.randf_range(-80,80),rng.randf_range(-25,25)))
		c.angle=rng.randf_range(-PI,PI);c.food=2 if c.key=="tag_splitter" else 3;c.bullet_food=1
		if trial%4==0:c.id=float(c.id)
		s.cells.append(c)
	s.begin_battle();s.spawn_queue.clear()
	for i in range(12):
		s.spawn_virus({"type":"pusher" if i%3==0 and s.experimental else "basic","lane":0,"p":Vector2.ZERO})
		var v=s.viruses.back();v.p=Vector2(rng.randf_range(-140,140),rng.randf_range(-40,40));v.emerging=false;v.jump=i%7==0;v.tag=1e12 if i%5==0 else 0.0;v.hp=1+i%3
		if trial%4==0:v.id=float(v.id)
	for i in range(24):
		var p={"kind":["bullet","tag","bullet","food"][i%4],"p":Vector2(rng.randf_range(-180,180),rng.randf_range(-40,40)),"v":Vector2(rng.randf_range(-12000,12000),rng.randf_range(-50,50)),"life":0.001 if i%5==0 else 4.0,"r":rng.randf_range(0,20),"owner":-1,"split":i%3==0}
		if i%6==0:p.owner=s.cells[i%8].id
		if i%13==0:p.life=0.0
		s.particles.append(p)
	# Guaranteed ordered recipe/split cases, ahead of random particles.
	var target=s.cells[trial%4];target.p=Vector2(500,0);target.angle=PI/2;target.food=2 if target.key=="tag_splitter" else 3
	for i in range(3):s.particles.push_front({"kind":"tag" if target.key=="tag_splitter" else "bullet","p":target.p,"v":Vector2(600,0),"life":4.0,"r":5.0,"owner":-1})
	return s
func run():
	var comparison=load("res://tests/fixtures/projectile_pass_comparison.gd").new()
	var coverage={}
	for trial in range(96):
		var a=build(false,trial);var b=build(true,trial)
		for tick in range(3):
			var delta=[1.0/60,1.0/120,1.0/30][tick]
			a.advance_projectiles_web(delta,delta*1.5);native_pass(b,delta,delta*1.5)
			if not comparison.same(a,b) or a.blasts!=b.blasts:
				for key in ["cells","viruses","particles","events","effects","pending_cells","blasts"]:
					if a.get(key)!=b.get(key):print("PROJECTILE_CASE_DIFF ",trial,"/",tick," ",key)
				return {"passed":false,"trial":trial,"tick":tick}
		for e in a.events:coverage[e.event]=int(coverage.get(e.event,0))+1
	return {"passed":true,"trials":96,"passes":288,"coverage":coverage}
