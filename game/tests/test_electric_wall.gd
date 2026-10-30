extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var c=s.make_cell("electric_wall",Vector2.ZERO);var b=s.make_cell("wall",Vector2(40,0));s.cells=[c,b]
	var pair=Vector2i(c.id,b.id);s.physics.contacts[pair]=true
	s.experiments.electric_contacts(s,c,0.02)
	var one=c.charge;assert(one>0)
	for i in range(60):s.experiments.electric_contacts(s,c,0.02)
	assert(c.charge==one,"continuous contact never rearms")
	s.physics.contacts.clear()
	for i in range(14):s.experiments.electric_contacts(s,c,0.02)
	s.physics.contacts[pair]=true;s.experiments.electric_contacts(s,c,0.02)
	assert(c.charge==2*one,"outside-contact cooldown rearms target")
	s.physics.contacts.clear();s.physics.contacts[Vector2i(-2,c.id)]=true
	for i in range(30):s.experiments.electric_contacts(s,c,0.02)
	assert(c.charge==2*one,"Core contact cannot generate charge")
	print("PASS: Electric Wall contact lifetime, rearm and Core exclusion")
	quit()
