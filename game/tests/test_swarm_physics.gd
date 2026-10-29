extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12);s.gym_mode=true;s.begin_battle();s.spawn_queue=[]
	for kind in ["swarmer","basic"]:s.spawn_virus({"type":kind,"lane":0,"p":Vector2(500+s.viruses.size()*19,0)})
	var a=s.viruses[0];var b=s.viruses[1];s.join_swarm_contacts();s.bonds.prepare(s)
	var distance=a.p.distance_to(b.p)
	check(s.links.size()==1 and s.bonds.same_group(a.id,b.id),"MC-030: contact creates real rigid group")
	s.physics.impulse(s,a,Vector2(0,30),a.p+Vector2(8,0));s.bonds.project(s)
	check(s.physics.velocity(b).length()>0,"MC-030: impulse propagates to joined body")
	for i in range(15):s.update(1.0/60)
	check(absf(a.p.distance_to(b.p)-distance)<0.01,"MC-030: welded distance survives motion without teleporting to host")
	b.alive=false;s.update(1.0/60)
	check(s.links.is_empty() and a.host==-1,"MC-030: death releases physical attachment")
	quit(errors)
