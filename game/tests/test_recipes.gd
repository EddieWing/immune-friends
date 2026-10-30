extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(19,12)
	var mortar=s.make_cell("mortar",Vector2.ZERO);s.cells=[mortar]
	mortar.food=9;s.proteins.consumed(s,mortar)
	check(mortar.food==5 and s.pending_cells.size()==1,"recipe subtracts exact cost and preserves excess")
	s.proteins.consumed(s,mortar)
	check(s.pending_cells.size()==1,"recipe cannot repeat during cooldown")
	s.proteins.tick(s,mortar,0.3)
	check(s.pending_cells.size()==1,"cooldown expiry alone does not trigger stored recipe")
	s.proteins.consumed(s,mortar)
	check(mortar.food==1 and s.pending_cells.size()==2,"next arrival triggers ready stored recipe")
	quit(errors)
