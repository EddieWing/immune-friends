extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(12,12)
	var a=s.make_cell("accelerator",Vector2.ZERO)
	var b=s.make_cell("bond",Vector2(40,0))
	var c=s.make_cell("turret",Vector2(80,0));s.cells=[a,b,c]
	s.links=[{"a":a.id,"b":b.id},{"a":b.id,"b":c.id}]
	check(s.ability_targets(a)==[b.id],"MC-012: Accelerator only direct neighbours")
	a.key="radar"
	check(s.ability_targets(a).size()==2 and not s.ability_reaches(a,a.id),"MC-012: Radar reaches whole network except itself")
	a.key="kinetic_bond"
	check(s.ability_reaches(a,a.id) and s.ability_reaches(a,c.id),"MC-012: Kinetic Connected includes itself")
	a.key="swapper"
	check(s.ability_targets(a)==[b.id],"MC-012: Swapper only direct neighbours")
	a.key="bodyguard";b.alive=false
	check(not s.ability_reaches(a,c.id),"MC-012: dead intermediate breaks effect path")
	a.alive=false
	check(s.ability_targets(a).is_empty(),"MC-012: dead provider has no recipients")
	quit(errors)
