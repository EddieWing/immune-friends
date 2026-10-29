extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=0
func check(ok,message):
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok:failures+=1
func setup():
	var s=Sim.new();s.reset(123,12);s.gym_mode=true;s.blood=[];s.blood_links=[]
	return s
func add(s,key,p):
	var body=s.make_cell(key,p);s.cells.append(body);return body
func start(s):
	s.begin_battle();s.spawn_queue.clear()
func _initialize():call_deferred("run")
func run():
	var s=setup()
	var bond=add(s,"bond",Vector2.ZERO)
	var far=add(s,"turret",Vector2(100,0))
	var wall=add(s,"wall",Vector2(80,0))
	var near=add(s,"turret",Vector2(55,0))
	s.rebuild_links()
	check(s.links.size()==2 and s.links.any(func(l):return l.b==wall.id) and not s.links.any(func(l):return l.b==far.id),"MC-003: fixture-aware query includes wall, excludes distant circle")
	wall.angle=PI/2;s.rebuild_links()
	check(s.links.size()==1,"MC-003: rotated wall changes eligibility")
	s.blood=[{"id":0,"alive":true,"p":Vector2(0,40)}]
	s.rebuild_links()
	check(s.links.size()==2 and s.links.any(func(l):return l.b==s.core_endpoint(s.blood[0])),"MC-003: ordinary Bond accepts Core and honors catalog limit")
	near.p=Vector2(400,0);s.update(1.0/60)
	check(not s.links.any(func(l):return l.b==near.id),"MC-003: preparation refreshes links after movement")
	s=setup();bond=add(s,"bond",Vector2.ZERO)
	var motor=add(s,"tackle",Vector2(-55,0))
	wall=add(s,"wall",Vector2(70,0));wall.angle=0.3
	start(s)
	var angle_delta=wall.angle-motor.angle
	var distance=wall.p.distance_to(motor.p)
	for i in range(90):s.update(1.0/60)
	check(motor.p.x>motor.start.x+15 and wall.p.x>wall.start.x+15,"MC-004: motor tows the entire welded construction")
	check(absf(wall.p.distance_to(motor.p)-distance)<0.02 and absf(wrapf(wall.angle-motor.angle-angle_delta,-PI,PI))<0.001,"MC-004: distances and relative angles stay rigid under towing")
	s.push_object(wall,Vector2(0,20),"cell",wall.p+Vector2(35,0))
	s.update(1.0/60)
	check(absf(s.physics.angular_velocity(bond))>0.01 and absf(s.physics.angular_velocity(bond)-s.physics.angular_velocity(wall))<0.001,"MC-004: off-centre impulse rotates the whole construction")
	var late=add(s,"turret",bond.p+Vector2(0,40));s.rebuild_links()
	check(not s.links.any(func(l):return l.a==late.id or l.b==late.id),"MC-004: battle never selects new neighbours")
	s.damage_cell(bond,999,true);s.update(1.0/60)
	check(s.links.is_empty() and s.bonds.groups.is_empty(),"MC-004: death splits construction without reconnecting")
	s=setup();motor=add(s,"tackle",Vector2.ZERO);wall=add(s,"wall",Vector2(59,0))
	start(s);s.update(1.0/60)
	check(motor.get("friendly_stun",0)>0,"MC-006: friendly fixture contact suspends propulsion")
	wall.p=Vector2(300,200)
	s.physics.state(motor).v=Vector2.ZERO
	var position=motor.p
	for i in range(12):s.update(1.0/60)
	check(motor.p.distance_to(position)<0.01,"MC-006: motor stays off for the contact timer")
	s.physics.impulse(s,motor,Vector2(0,60));s.update(1.0/60)
	check(motor.p.y>position.y,"MC-006: external impulse still moves a suspended motor")
	for i in range(30):s.update(1.0/60)
	check(motor.friendly_stun==0 and motor.p.x>position.x+1,"MC-006: propulsion resumes after 0.5 seconds")
	s=setup();var gun=add(s,"turret",Vector2.ZERO);wall=add(s,"wall",Vector2(-59,0))
	start(s);s.spawn_virus({"type":"basic","lane":0})
	var virus=s.viruses.back();virus.emerging=false;virus.p=Vector2(100,0);virus.freeze=100;virus.cool=100;virus.hp=1000
	s.update(1.0/60);gun.cool=0;s.update(1.0/60)
	check(gun.get("friendly_stun",0)>0 and s.events.any(func(e):return e.event=="attack_fired"),"MC-006: shooting remains active during friendly contact suspension")
	print("BOND ITERATIONS failures: ",failures)
	quit(1 if failures else 0)
