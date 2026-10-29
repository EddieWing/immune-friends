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
	s=Sim.new();s.reset(42,12)
	c=s.make_cell("wall",Vector2.ZERO);c.hp=5
	var bridge=s.make_cell("bond",Vector2(50,0))
	var guard=s.make_cell("bodyguard",Vector2(100,0));guard.hp=2
	s.cells=[c,bridge,guard];s.links=[{"a":c.id,"b":bridge.id},{"a":bridge.id,"b":guard.id}]
	s.damage_cell(c,3)
	check(c.hp==4 and not guard.alive,"MC-008: network guard absorbs own HP, overflow reaches target")
	s.damage_cell(c,1)
	check(c.hp==3,"MC-008: dead guard cannot intercept")
	guard.alive=true;guard.hp=4;bridge.alive=false
	s.damage_cell(c,1)
	check(c.hp==2 and guard.hp==4,"MC-008: broken network removes protection")
	s=Sim.new();s.reset(42,12)
	var core=s.blood[0]
	guard=s.make_cell("bodyguard",core.p+Vector2(40,0));guard.hp=2;s.cells=[guard]
	s.links=[{"a":guard.id,"b":s.core_endpoint(core)}]
	s.spawn_virus({"type":"basic","lane":0,"p":core.p});v=s.viruses[0];v.hp=3
	s.physics.contacts={Vector2i(s.core_endpoint(core),v.id):true};s.resolve_cell_contacts()
	check(not core.alive and not guard.alive and not v.alive,"MC-009: Core overflow and lethal counterattack")
	check(s.round_losses.core==1 and s.round_losses.viruses==1 and s.round_losses.cells==1,"MC-009: each death counted exactly once")
	s.resolve_cell_contacts()
	check(s.round_losses.core==1 and s.round_losses.viruses==1,"MC-009: repeated dead contact adds no losses")
	s=Sim.new();s.reset(42,12);core=s.blood[0]
	guard=s.make_cell("bodyguard",core.p+Vector2(40,0));guard.hp=4;s.cells=[guard]
	s.links=[{"a":guard.id,"b":s.core_endpoint(core)}]
	s.spawn_virus({"type":"basic","lane":0,"p":core.p});v=s.viruses[0];v.hp=2
	s.hit_core(core,v)
	check(core.alive and guard.hp==2 and not v.alive and s.round_losses.viruses==1,"MC-009: fully protected Core still kills attacker and drops food")
	s=Sim.new();s.reset(42,12);s.begin_battle();s.spawn_queue=[]
	core=s.blood[0];s.spawn_virus({"type":"basic","lane":0,"p":core.p+Vector2(5,0)});v=s.viruses[0]
	s.update(1.0/60)
	check(not v.alive and s.round_losses.core>0,"MC-009 integration: solver emits Core-virus contacts")
	quit(failures)
