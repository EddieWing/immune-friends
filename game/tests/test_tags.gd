extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12)
	s.spawn_virus({"type":"basic","lane":0,"p":Vector2.ZERO});var v=s.viruses[0];v.p=Vector2.ZERO
	var p={"kind":"tag","p":Vector2.ZERO,"v":Vector2.ZERO,"life":1e12,"r":2.0,"owner":-1}
	s.proteins.resolve_tag(s,p,p.p,p.p)
	check(v.tag>1000 and v.freeze==1.5,"tag persists for virus life, first hit suspends 1.5 seconds")
	v.freeze=0.25;p.life=1e12;s.proteins.resolve_tag(s,p,p.p,p.p)
	check(v.freeze==0.25,"repeat hit does not refresh suspension")
	p.p=Vector2(-50,0);p.v=Vector2.ZERO;v.tag=0
	s.proteins.steer_tag(s,p,0.1)
	check(p.v.x>0,"tag steers toward untagged virus")
	var sprayer=s.make_cell("tag_sprayer",Vector2.ZERO);s.cells=[sprayer];s.begin_battle();s.gym_mode=true;s.spawn_queue=[];s.viruses=[]
	check(sprayer.tags==30,"normal Sprayer starts with 30 tags")
	for i in range(300):s.update(1.0/60)
	check(sprayer.tags==0 and s.particles.size()==30,"Sprayer stops after finite ammunition and tags do not expire early")
	quit(errors)
