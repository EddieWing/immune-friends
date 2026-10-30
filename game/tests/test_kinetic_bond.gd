extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var a=s.make_cell("kinetic_bond",Vector2.ZERO);var b=s.make_cell("wall",Vector2(40,0));s.cells=[a,b]
	s.links=[{"a":a.id,"b":b.id,"owner":a.id}]
	s.phase="battle";var hp=b.hp
	a.travel_x=0;a.travel_y=0;b.travel_x=0;b.travel_y=0
	b.p.x=400;s.experiments.tick(s,b,0.01)
	check(b.hp==hp,"recipient movement alone does not earn healing")
	a.p.x=20*s.rules.scale;s.experiments.tick(s,a,0.01)
	check(b.hp==hp,"reference threshold is strict greater-than")
	a.p.x+=1;s.experiments.tick(s,a,0.01)
	check(b.hp==hp+1 and a.hp==a.max_hp+1,"provider path heals connected set including itself")
	s.phase="shop";a.p.x+=100;s.experiments.tick(s,a,0.01)
	check(b.hp==hp+1,"preparation reposition does not trigger heal")
	quit(errors)
