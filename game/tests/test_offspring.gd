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
	quit(errors)
