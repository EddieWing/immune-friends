extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12);s.begin_battle();s.spawn_queue=[]
	s.spawn_virus({"type":"jumper","lane":0,"p":Vector2(8000,0)})
	var v=s.viruses[0];v.tag=100;v.freeze=100;v.jump=true
	check(v.lifespan>=12 and v.lifespan<14,"MC-026: lifespan randomly 12–14 seconds from spawn")
	v.lived=v.lifespan-0.01;s.update(1.0/60)
	check(not v.alive and s.round_losses.viruses==1 and s.particles.any(func(p):return p.kind=="food"),"MC-026: age kills even tagged/frozen/jumping and drops food")
	check(s.phase=="battle","MC-026: result waits for effects")
	for i in range(60):s.update(1.0/60)
	check(s.phase=="recap","MC-026: settles into recap")
	s=Sim.new();s.reset(42,12);s.begin_battle()
	s.spawn_queue=[{"type":"basic","lane":0,"p":Vector2(8000,0),"due":300.0}]
	s.elapsed=181;s.update(1.0/60)
	check(s.phase=="battle" and s.blood.all(func(b):return b.alive),"MC-026: pending release survives old timeout without Core penalty")
	quit(errors)
