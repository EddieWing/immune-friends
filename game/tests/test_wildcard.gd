extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:failures+=1
func _initialize():
	for reverse in [false,true]:
		for ranks in [[1,1],[2,1],[2,2]]:
			var s=Sim.new();s.reset(42,12)
			var c=s.make_cell("survivor_bomb",Vector2(123,40))
			var w=s.make_cell("wildcard",Vector2(-50,0))
			c.rank=ranks[0];w.rank=ranks[1];c.max_hp=7;w.max_hp=4
			c.sale=3;w.sale=5;c.radius_growth=16;c.angle=1.2
			s.cells=[c,w]
			check(s.merge(w,c) if reverse else s.merge(c,w),"both drag directions / ranks %s"%[ranks])
			check(s.cells.size()==1 and s.cells[0].id==c.id and c.p==Vector2(123,40) and c.angle==1.2,"ordinary identity, position and pose retained")
			check(c.hp==11 and c.max_hp==11 and c.sale==7 and c.radius_growth==16,"permanent bonuses transfer once")
			check(c.rank==mini(3,ranks[0]+ranks[1]) and c.copies==ranks[0]+ranks[1],"progress and contributing copies")
			check(s.reward_choices.size()==(1 if c.rank==3 else 0),"one reward on promotion")
			check(not s.merge(w,c),"consumed Wildcard cannot be reused")
	var s=Sim.new();s.reset(42,12)
	var a=s.make_cell("wildcard",Vector2.ZERO);var b=s.make_cell("wildcard",Vector2(50,0));s.cells=[a,b]
	check(s.merge(a,b) and s.cells[0].id==b.id and b.rank==2,"Wildcard + Wildcard follows original recipient swap")
	a=s.make_cell("wall",Vector2.ZERO);a.rank=3;s.cells.append(a)
	check(not s.merge(a,b) and not s.merge(b,a),"elite ordinary rejected both directions")
	a.rank=1;b.rank=3
	check(not s.merge(a,b) and not s.merge(b,a),"elite Wildcard rejected both directions")
	s=Sim.new();s.reset(42,12)
	a=s.make_cell("wildcard",Vector2.ZERO);s.cells=[a];s.offers=["wall"];s.money=2
	check(s.purchase(0,Vector2(20,0)),"ordinary purchase directly merges into Wildcard")
	check(s.cells.size()==1 and s.cells[0].key=="wall" and s.cells[0].id!=a.id and s.cells[0].p==Vector2(20,0),"purchase keeps ordinary bought object")
	print("RESULT: Wildcard, %d failures"%failures)
	quit(1 if failures else 0)
