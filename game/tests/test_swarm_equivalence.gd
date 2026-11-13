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
		if i==30:
			for s in [a,b]:s.apply_tuning("virus:swarmer",{"physics/density":0.37,"speed_multiplier":1.7})
		if i==45:
			a.viruses[0].alive=false;b.viruses[0].alive=false
		a.update(1.0/60);b.update(1.0/60)
		assert(a.viruses==b.viruses and a.cells==b.cells and a.blood==b.blood,"Body state differs")
		assert(a.links==b.links and a.events==b.events and a.physics.states==b.physics.states,"Swarm logic differs")
	# Keep actors apart so attachments cannot hide the nine-force path. Change
	# tuning between calls and preserve nonzero velocities from previous impulses.
	for s in [a,b]:
		s.links=[]
		for i in range(s.viruses.size()):
			s.viruses[i].p=Vector2(i%6*35,i/6*35);s.viruses[i].alive=true
	for i in range(120):
		for s in [a,b]:
			s.apply_tuning("virus:swarmer",{"physics/density":0.1+i*0.017,"speed_multiplier":0.5+i*0.02})
			for v in s.viruses:
				if v.type=="swarmer":s.update_swarm_attraction(v,1.0/60)
		assert(a.physics.states==b.physics.states and a.events==b.events,"Attraction impulses differ with tuning")
	print("PASS: 90 full simulation steps match original swarm loops with unrelated links, dense contacts and death")
	print("PASS: 120 nine-neighbour attraction passes match with changing density and speed")
	# More than nine equidistant candidates exercise the original unstable tie
	# order; choosing the same set in a new order can still change Float32 forces.
	var ring=[Vector2(40,0),Vector2(24,32),Vector2(0,40),Vector2(-24,32),Vector2(-40,0),Vector2(-24,-32),Vector2(0,-40),Vector2(24,-32)]
	for tick in range(48):
		for s in [a,b]:
			for i in range(s.viruses.size()):
				var v=s.viruses[i];v.alive=true;v.jump=false;v.freeze=0
				v.p=Vector2.ZERO if i==0 else ring[(i+tick)%ring.size()]
			s.viruses[0].type="swarmer"
			s.update_swarm_attraction(s.viruses[0],1.0/60)
		assert(a.physics.states==b.physics.states and a.events==b.events,"Equal-distance attraction order differs")
	print("PASS: 48 equal-distance swarm selections retain the legacy impulse order")
	quit()
