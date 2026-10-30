extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var gun=s.make_cell("gatling",Vector2.ZERO);var other=s.make_cell("turret",Vector2.ZERO);s.cells=[gun,other]
	s.spawn_virus({"type":"basic","lane":0,"p":Vector2.ZERO});var v=s.viruses[0]
	s.damage_virus(v,99,{"owner":other.id});check(gun.get("kills",0)==0,"other owner's kill does not speed up Gatling")
	s.spawn_virus({"type":"basic","lane":0,"p":Vector2.ZERO});v=s.viruses[-1]
	s.damage_virus(v,99,{"owner":gun.id});s.damage_virus(v,99,{"owner":gun.id})
	check(gun.kills==1,"own kill counted exactly once")
	gun.kills=100;check(is_equal_approx(s.interval_of(gun),0.2),"Gatling interval never drops below 0.2 seconds")
	s.begin_battle();check(gun.kills==0,"kill bonus resets at battle start")
	quit(errors)
