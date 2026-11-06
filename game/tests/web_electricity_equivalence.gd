extends Node
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
var report: Label
func fail(message):
	report.text="FAIL: "+message
	push_error(message)
func _ready():
	report=Label.new();report.position=Vector2(40,40);report.add_theme_font_size_override("font_size",24);add_child(report)
	report.text="Electricity equivalence: running browser kernel..."
	await get_tree().process_frame
	if not OS.has_feature("web"):
		fail("This harness requires the web build");return
	var checks=0
	for seed_value in [42,91,147]:
		var a=fixture(seed_value);var b=fixture(seed_value);b.electricity=Legacy.new()
		if a.electricity.web_kernel==null:
			fail("Browser kernel missing");return
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
			if not (a.cells==b.cells and a.viruses==b.viruses and a.particles==b.particles):
				fail("Body state differs at tick %s"%tick);return
			if not (a.electricity.currents==b.electricity.currents and a.electricity.step==b.electricity.step):
				fail("Current state differs");return
			if not (a.events==b.events and a.effects==b.effects and a.next_id==b.next_id):
				fail("Observable electric results differ");return
			checks+=1
			if tick%20==0:await get_tree().process_frame

	# Strict boundary and negative-coordinate checks catch JS/Vector2 rounding differences.
	for reach in [5.5,100.0,123.456]:
		for origin in [-240.0,0.0,4096.0]:
			for epsilon in [-0.0001,0.0,0.0001]:
				var a=fixture(42);var b=fixture(42);b.electricity=Legacy.new()
				for sim in [a,b]:
					sim.cells=sim.cells.slice(0,1);sim.viruses=sim.viruses.slice(0,1);sim.particles.clear()
					sim.rules.charge_range=reach;sim.cells[0].p=Vector2(origin,-origin);sim.cells[0].charge=3
					sim.viruses[0].p=Vector2(origin+reach+epsilon,-origin)
				for tick in range(3):
					a.electricity.update(a);b.electricity.update(b)
					if a.cells!=b.cells or a.viruses!=b.viruses or a.electricity.currents!=b.electricity.currents or a.events!=b.events or a.effects!=b.effects:
						fail("Reach boundary differs: %s/%s/%s"%[reach,origin,epsilon]);return
					checks+=1
				await get_tree().process_frame
	# Paired deterministic workload: compare the JIT with the current native graph,
	# including serialization overhead. This is CPU timing, not a game FPS claim.
	var a=fixture(147);var b=fixture(147);b.electricity.web_kernel=null
	var web_us=0;var native_us=0
	for tick in range(400):
		for sim in [a,b]:
			if tick%10==0:
				for c in sim.cells:c.charge=3
		var started=Time.get_ticks_usec();a.electricity.update(a);web_us+=Time.get_ticks_usec()-started
		started=Time.get_ticks_usec();b.electricity.update(b);native_us+=Time.get_ticks_usec()-started
		if a.cells!=b.cells or a.viruses!=b.viruses or a.electricity.currents!=b.electricity.currents or a.events!=b.events or a.effects!=b.effects:
			fail("Paired timing fixture differs at %s"%tick);return
		checks+=1
		if tick%20==0:await get_tree().process_frame
	print("PASS: ",checks," electric equivalence steps: empty, recharge, sources, death, jump, particles, disconnected currents and reconnecting islands")
	report.text="PASS: %d browser equivalence steps\nBodies, currents, damage, events, effects and IDs match.\nElectricity CPU: web %.3f ms / native %.3f ms per step"%[checks,web_us/400000.0,native_us/400000.0]
