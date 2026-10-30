extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var a=s.make_cell("swapper",Vector2.ZERO);var b=s.make_cell("wall",Vector2(45,0))
	s.blood.clear();s.cells=[a,b];a.max_hp=2;b.max_hp=9;a.hp=0;a.alive=false;b.hp=3
	s.phase="recap";s.next_round()
	assert(a.hp==9 and a.max_hp==9 and b.hp==2,"restored permanent health exchanged")
	s.next_round();s.rebuild_links()
	assert(a.hp==9 and b.hp==2,"repeated transition/UI does not exchange again")
	print("PASS: Swapper restoration, nearest direct partner and once-only transition")
	quit()

