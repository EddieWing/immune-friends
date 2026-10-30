extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize():
	var s=Sim.new();s.reset(42,12);s.blood.clear();s.rules.charge_range=100
	var a=s.make_cell("zapper",Vector2.ZERO);var relay=s.make_cell("wall",Vector2(90,0));var m=s.make_cell("electromagnet",Vector2(180,0));s.cells=[a,relay,m];a.charge=2
	assert(s.range_of(m)==0,"empty magnet has zero field")
	for i in range(8):s.electricity.update(s)
	assert(m.charge==2 and a.charge==0,"magnet draws through relay instead of stealing nearby charge")
	assert(is_equal_approx(s.range_of(m),10*s.rules.scale),"normal conversion five per charge")
	m.rank=3;assert(is_equal_approx(s.range_of(m),20*s.rules.scale),"elite conversion ten per charge")
	print("PASS: magnet relay transfer, empty field and normal/elite range")
	quit()
