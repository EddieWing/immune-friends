extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(12,12)
	var near=s.make_cell("turret",Vector2(35,0));near.hp=3
	var far=s.make_cell("turret",Vector2(110,0));far.hp=3;s.cells=[near,far]
	s.start_blast(Vector2.ZERO,120)
	s.advance_blasts(0.1)
	check(near.hp==3 and far.hp==3,"MC-010: blast does not hit whole area immediately")
	s.advance_blasts(0.1)
	check(near.hp==2 and far.hp==3,"MC-010: front hits nearby ally first")
	s.advance_blasts(0.5)
	check(near.hp==2 and far.hp==2,"MC-010: one hit per target")
	check(s.physics.velocity(near).x>0,"MC-010: physical outward impulse")
	var bomb=s.make_cell("bomb",Vector2(50,0));bomb.hp=1;s.cells=[bomb]
	s.blasts.clear();s.start_blast(Vector2.ZERO,120);s.advance_blasts(0.5)
	check(not bomb.alive and s.blasts.size()==2,"MC-010: bomb death launches independent chained front")
	s=Sim.new();s.reset(12,12);s.experimental=true
	near=s.make_cell("turret",Vector2(25,0));s.cells=[near];var hp=near.hp
	s.spawn_virus({"type":"pusher","lane":0,"p":Vector2.ZERO})
	s.spawn_virus({"type":"basic","lane":0,"p":Vector2(15,0)})
	s.damage_virus(s.viruses[0],999);s.advance_blasts(0.2)
	check(near.hp==hp and s.physics.velocity(near).x>0,"MC-031: Pusher front pushes immune body without damage")
	check(s.physics.velocity(s.viruses[1])==Vector2.ZERO and s.blood.all(func(b):return b.alive),"MC-031: viruses and Core excluded from force target filter")
	quit(errors)
