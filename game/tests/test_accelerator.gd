extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var a=s.make_cell("accelerator",Vector2.ZERO);var b=s.make_cell("turret",Vector2(40,0));s.cells=[a,b]
	s.links=[{"a":a.id,"b":b.id,"owner":a.id}]
	a.food=2;s.proteins.consumed(s,a)
	check(a.food==0 and b.cool_reserve==2 and b.speed_buff==1,"food grants cooldown reserve without movement bonus")
	b.cool=1.2;s.proteins.accelerate_cooldown(b)
	check(is_equal_approx(b.cool,0.2) and is_equal_approx(b.cool_reserve,1),"reserve preserves minimum wait and unspent seconds")
	b.cool=0.1;s.proteins.accelerate_cooldown(b)
	check(is_equal_approx(b.cool_reserve,1),"short wait does not waste reserve")
	s.links=[];a.food=2;s.proteins.consumed(s,a)
	check(is_equal_approx(b.cool_reserve,1),"broken bond prevents reserve transfer")
	quit(errors)
