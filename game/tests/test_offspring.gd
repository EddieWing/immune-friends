extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var c=s.make_cell("mortar",Vector2.ZERO);s.cells=[c];c.rank=3;c.food=4
	s.proteins.consumed(s,c)
	var baby=s.pending_cells[0]
	check(baby.rank==3 and baby.hp==s.stat_of(baby,"hp"),"elite Mortar creates elite Bomb with catalog stats")
	check(baby.temporary and baby.p.distance_to(c.p)>s.physics.radius(c)+s.physics.radius(baby),"offspring spawns outside producer and is temporary")
	check(s.physics.state(baby).v.length()>0 and not baby.has("launch_remaining"),"launch is a physical impulse")
	s.cells.append(baby);s.phase="recap";s.next_round()
	check(not s.cells.has(baby),"offspring is removed from permanent next-round squad")
	s.experimental=true
	var factory=s.make_cell("seeker_factory",Vector2.ZERO);factory.rank=3;factory.food=2;factory.bullet_food=3
	s.pending_cells.clear();s.proteins.consumed(s,factory)
	check(s.pending_cells.size()==1 and s.pending_cells[0].rank==1,"elite Factory creates normal Seeker as original branch does")
	check(factory.food==1 and factory.bullet_food==1,"Factory preserves excess of each ingredient")
	quit(errors)
