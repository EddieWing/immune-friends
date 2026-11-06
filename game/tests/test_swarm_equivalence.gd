extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Legacy=preload("res://tests/legacy_swarm_sim.gd")
func fill(s):
	s.reset(42,12);s.gym_mode=true;s.begin_battle();s.spawn_queue=[]
	for i in range(36):
		s.spawn_virus({"type":"swarmer" if i%3==0 else "basic","lane":0,"p":Vector2(300+i%6*19,i/6*19)})
		s.viruses[-1].hp=100
	for i in range(6):
		var a=s.make_cell("wall",Vector2(-100,i*40));s.cells.append(a)
		var b=s.make_cell("bond",Vector2(-160,i*40));s.cells.append(b)
		s.links.append({"a":a.id,"b":b.id,"owner":a.id,"rest":60,"swarm":true})
func _initialize():
	var a=Sim.new();var b=Legacy.new();fill(a);fill(b)
	for i in range(90):
		if i==45:
			a.viruses[0].alive=false;b.viruses[0].alive=false
		a.update(1.0/60);b.update(1.0/60)
		assert(a.viruses==b.viruses and a.cells==b.cells and a.blood==b.blood,"Body state differs")
		assert(a.links==b.links and a.events==b.events and a.physics.states==b.physics.states,"Swarm logic differs")
	print("PASS: 90 full simulation steps match original swarm loops with unrelated links, dense contacts and death")
	quit()
