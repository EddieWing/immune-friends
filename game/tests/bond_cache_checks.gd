extends RefCounted
# Frozen pre-optimization solver is the oracle; compare actual bodies and events.
const Sim=preload("res://scripts/simulation.gd")
const Legacy=preload("res://tests/legacy_bond_system.gd")
static func fixture(seed_value,legacy=false):
	var s=Sim.new();s.reset(seed_value,12);s.gym_mode=true
	s.cells.clear();s.blood=s.blood.slice(0,3);s.viruses.clear()
	s.rebuild_blood_links();s.blood_velocity.clear()
	if legacy:s.bonds=Legacy.new()
	for i in range(12):
		var c=s.make_cell(["wall","bond","tackle","orbiter"][i%4],Vector2(-180+i%4*70,-120+i/4*70))
		c.angle=(i%5)*0.17;c.hp=1000;c.max_hp=1000;s.cells.append(c)
	s.begin_battle();s.spawn_queue.clear();s.links.clear()
	for i in range(10):
		if i==5:continue
		s.links.append({"a":s.cells[i].id,"b":s.cells[i+1].id,"rest":70.0})
	s.links.append({"a":s.cells[0].id,"b":s.core_endpoint(s.blood[0]),"rest":80.0})
	s.bonds.lock(s)
	return s
static func change(s,tick):
	if tick==8:s.links[0].offset+=Vector2(2,-3)
	if tick==12:s.links[1].relative_angle+=0.13
	if tick==16:s.links.reverse()
	if tick==20:s.cells[3].alive=false
	if tick==24:s.links.append({"a":s.cells[2].id,"b":999999,"rest":50,"locked":false})
	if tick==28:s.links[0].locked=false
	if tick==32:s.tuning["wall"]={"physics/density":2.7}
	if tick==36:s.phase="shop";s.bonds.prepare(s);s.phase="battle"
	if tick==40:s.links.clear()
	if tick==44:
		s.links=[{"a":s.cells[5].id,"b":s.cells[6].id,"rest":65.0}];s.bonds.lock(s)
	if tick%7==0:s.physics.impulse(s,s.cells[6],Vector2(11,-9),s.cells[6].p+Vector2(17,8))
static func run():
	var checks=0;var old_us=0;var new_us=0
	for seed_value in [11,42,83]:
		var a=fixture(seed_value);var b=fixture(seed_value,true)
		for tick in range(90):
			change(a,tick);change(b,tick)
			a.update(1.0/60);b.update(1.0/60)
			if a.cells!=b.cells or a.blood!=b.blood or a.links!=b.links or a.physics.states!=b.physics.states or a.physics.contacts!=b.physics.contacts or a.events!=b.events or a.rng.state!=b.rng.state:
				return {"ok":false,"message":"Full simulation differs at seed %s tick %s"%[seed_value,tick]}
			if a.bonds.groups!=b.bonds.groups or a.bonds.membership!=b.bonds.membership:
				return {"ok":false,"message":"Topology/rest poses differ at tick %s"%tick}
			checks+=1
	# Repeated projection uses the real cached physics materials, as in step().
	var a=fixture(42);var b=fixture(42,true)
	a.update(1.0/60);b.update(1.0/60)
	a.physics.stepping=true;b.physics.stepping=true
	for tick in range(600):
		for s in [a,b]:
			s.cells[0].p+=Vector2(0.1,-0.2)
			s.physics.state(s.cells[0]).w+=0.001
		var started=Time.get_ticks_usec()
		if tick%2==0:
			a.bonds.prepare(a);a.bonds.project(a);new_us+=Time.get_ticks_usec()-started
			started=Time.get_ticks_usec();b.bonds.prepare(b);b.bonds.project(b);old_us+=Time.get_ticks_usec()-started
		else:
			b.bonds.prepare(b);b.bonds.project(b);old_us+=Time.get_ticks_usec()-started
			started=Time.get_ticks_usec();a.bonds.prepare(a);a.bonds.project(a);new_us+=Time.get_ticks_usec()-started
		if a.cells!=b.cells or a.blood!=b.blood or a.physics.states!=b.physics.states:
			return {"ok":false,"message":"Projection differs at tick %s"%tick}
		checks+=1
	return {"ok":true,"message":"%d exact comparisons; projection+prepare new %.3f ms / previous %.3f ms"%[checks,new_us/600000.0,old_us/600000.0]}
