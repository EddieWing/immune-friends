extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:failures+=1
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var c=s.make_cell("wall",Vector2.ZERO);c.hp=3;s.cells=[c]
	s.spawn_virus({"type":"basic","lane":0,"p":Vector2(20,0)})
	var v=s.viruses[0];v.hp=2
	s.physics.contacts={Vector2i(c.id,v.id):true}
	s.resolve_cell_contacts()
	check(c.hp==1 and not v.alive,"MC-007: reciprocal damage uses pre-contact health")
	check(s.round_losses.viruses==1,"MC-007: death registered once")
	s.resolve_cell_contacts()
	check(c.hp==1 and s.round_losses.viruses==1,"MC-007: dead attackers do not hit again")
	# Two simultaneous contacts snapshot the same initial attacker health.
	s=Sim.new();s.reset(42,12)
	c=s.make_cell("wall",Vector2.ZERO);c.hp=3;s.cells=[c]
	for i in range(2):
		s.spawn_virus({"type":"basic","lane":0,"p":Vector2(20,0)})
		s.viruses[i].hp=2
		s.physics.contacts[Vector2i(c.id,s.viruses[i].id)]=true
	s.resolve_cell_contacts()
	check(not c.alive and s.viruses.all(func(x):return not x.alive),"MC-007: all contacts snapshot before any damage")
	quit(failures)
