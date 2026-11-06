extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Legacy=preload("res://tests/legacy_electricity.gd")
func fixture(seed_value):
	var s=Sim.new();s.reset(seed_value,12);s.cells.clear();s.viruses.clear();s.particles.clear();s.blood.clear()
	s.rules.charge_range=100
	for i in range(12):
		var key=["zapper","generator","electric_wall","electromagnet","wall","bond"][i%6]
		var c=s.make_cell(key,Vector2(i%4*75,i/4*70));c.charge=0;s.cells.append(c)
	for i in range(32):
		s.spawn_virus({"type":"basic","lane":0,"p":Vector2(30+i%8*55,30+i/8*65)})
		var v=s.viruses[-1];v.p=Vector2(30+i%8*55,30+i/8*65);v.hp=100;v.jump=false
	# A disconnected island must not need a neighbour list until reached.
	if seed_value==147:
		for i in range(16,32):s.viruses[i].p+=Vector2(2000,0)
	for i in range(8):
		s.particles.append({"kind":"bullet","p":Vector2(i*80,100),"life":4.0,"r":5.0,"v":Vector2.ZERO,"owner":-1})
	return s
func _initialize():
	var checks=0
	for seed_value in [42,91,147]:
		var a=fixture(seed_value);var b=fixture(seed_value);b.electricity=Legacy.new()
		for tick in range(160):
			for s in [a,b]:
				if seed_value==147 and tick in [30,70]:
					for i in range(16,32):s.viruses[i].p+=Vector2(-2000 if tick==30 else 2000,0)
				if tick==25:
					# Isolated travelling current with a still-live source.
					s.electricity.currents[s.viruses[31].id]={"source":s.cells[0].id,"path":[s.viruses[31].id,s.cells[0].id]}
				if tick==50:s.particles[0].life=0
				if tick in [20,60,100]:s.cells[tick%4].charge=3
				if tick==40:s.cells[0].alive=false
				if tick==80:
					s.viruses[0].jump=true
					s.viruses[1].alive=false
				if tick==120:
					for c in s.cells:c.charge=0
				for v in s.viruses:v.p+=Vector2(sin(tick+v.id),cos(tick-v.id))*0.4
				s.electricity.update(s)
			assert(a.cells==b.cells and a.viruses==b.viruses and a.particles==b.particles,"Body state differs at tick %s"%tick)
			assert(a.electricity.currents==b.electricity.currents and a.electricity.step==b.electricity.step,"Current state differs")
			assert(a.events==b.events and a.effects==b.effects and a.next_id==b.next_id,"Observable electric results differ")
			checks+=1
	print("PASS: ",checks," electric equivalence steps: empty, recharge, sources, death, jump, particles, disconnected currents and reconnecting islands")
	quit()
