extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize():
	var s=Sim.new();s.reset(42,12);s.blood.clear();s.rules.charge_range=100
	var a=s.make_cell("zapper",Vector2.ZERO);var relay=s.make_cell("wall",Vector2(90,0));s.cells=[a,relay];a.charge=1
	s.spawn_virus({"type":"seeker","lane":0,"p":Vector2(180,0)})
	var v=s.viruses[0];v.p=Vector2(180,0);v.hp=3;v.jump=false
	s.electricity.update(s);assert(v.hp==3,"no instant reach across relay")
	for i in range(6):s.electricity.update(s)
	assert(v.hp==2 and a.charge==0,"one charge does one damage through relay")
	s.electricity.reset();s.cells=[a];a.charge=1;s.blood=[{"id":0,"p":Vector2(90,0),"alive":true}]
	for i in range(6):s.electricity.update(s)
	assert(v.hp==2 and a.charge==1,"Core cannot conduct")
	print("PASS: electrical path, delayed transfer, one damage and Core exclusion")
	quit()
