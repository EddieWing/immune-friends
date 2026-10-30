extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:failures+=1
func _initialize():
	for ranks in [[1,1],[2,1],[2,2]]:
		var s=Sim.new();s.reset(42,12)
		var a=s.make_cell("survivor_bomb",Vector2.ZERO)
		var b=s.make_cell("survivor_bomb",Vector2(50,0))
		a.rank=ranks[0];b.rank=ranks[1]
		a.max_hp=4;b.max_hp=7;a.hp=4;b.hp=7
		a.sale=3;b.sale=5;a.radius_growth=8;b.radius_growth=16
		s.cells=[a,b]
		check(s.merge(a,b),"merge ranks %s"%[ranks])
		check(a.rank==mini(3,ranks[0]+ranks[1]) and s.cells.size()==1,"one body and saturated rank")
		check(a.max_hp==11 and a.hp==11 and a.sale==7 and a.radius_growth==24,"HP, sale and permanent radius transfer once")
		check(a.copies==ranks[0]+ranks[1],"copy count survives saturated progress")
		check(s.reward_choices.size()==(1 if a.rank==3 else 0),"one reward only on promotion")
		check(not s.merge(a,b) and a.max_hp==11,"removed body cannot merge again")
		if a.rank==3:
			var c=s.make_cell(a.key,Vector2(100,0));s.cells.append(c)
			check(not s.merge(a,c) and not s.merge(c,a),"elite cannot merge in either direction")
	var s=Sim.new();s.reset(42,12)
	var c=s.make_cell("seeker",Vector2.ZERO);c.rank=3
	check(s.stat_of(c,"range")==40 and s.stat_of(c,"speed")==18,"elite overrides range and inherits ordinary speed")
	var a=s.make_cell("hungry_bomb",Vector2.ZERO);var b=s.make_cell("hungry_bomb",Vector2(30,0))
	a.radius_growth=9;b.radius_growth=7;s.cells=[a,b]
	s.merge(a,b);s.begin_battle()
	check(a.radius_growth==0,"temporary growth does not become a permanent merge bonus")
	print("RESULT: merge progression, %d failures"%failures)
	quit(1 if failures else 0)
