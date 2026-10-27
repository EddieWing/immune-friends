extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
var checks=0
func check(ok,label):
	checks+=1
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func setup():
	var s=Sim.new();s.reset();s.gym_mode=true;s.blood=[];s.blood_links=[]
	return s
func add(s,key,pos):
	var c=s.make_cell(key,pos);s.cells.append(c);return c
func advance(s,seconds):
	for i in range(roundi(seconds*120)):s.physics.step(s,1.0/120.0)
func reference_candidates(bodies):
	var grid={}
	for i in range(bodies.size()):
		var tile=Vector2i(floori(bodies[i].p.x/96.0),floori(bodies[i].p.y/96.0))
		if not grid.has(tile):grid[tile]=[]
		grid[tile].append(i)
	var pairs=[]
	for i in range(bodies.size()):
		var a=bodies[i]
		if a.get("jump",false) or a.get("emerging",false):continue
		var tile=Vector2i(floori(a.p.x/96.0),floori(a.p.y/96.0))
		for y in range(-1,2):
			for x in range(-1,2):
				for j in grid.get(tile+Vector2i(x,y),[]):
					if j<=i:continue
					var b=bodies[j]
					if b.get("jump",false) or b.get("emerging",false):continue
					if not a.has("key") and not b.has("key"):continue
					pairs.append(Vector2i(i,j))
	return pairs
func _initialize():
	var s=setup()
	var light=add(s,"seeker",Vector2(-200,0));var heavy=add(s,"wildcard",Vector2(200,0))
	s.push_object(light,Vector2(20,0),"cell",light.p)
	s.push_object(heavy,Vector2(20,0),"cell",heavy.p)
	check(light.p==Vector2(-200,0) and heavy.p==Vector2(200,0),"Push changes momentum, not position instantly")
	check(is_equal_approx(s.physics.velocity(light).x/s.physics.velocity(heavy).x,10),"Equal impulse gives heavy cell ten times less speed")
	advance(s,0.2)
	check(light.p.x+200>heavy.p.x-200 and heavy.p.x>200,"Mass difference affects displacement")
	check(light.p.x+200>28,"Ordinary push travels visibly within the first 200 ms")
	var velocity=s.physics.velocity(light).length()
	advance(s,0.2)
	check(s.physics.velocity(light).length()<velocity and s.physics.velocity(light).length()>0,"Water drag gradually slows a drifting body")
	s=setup()
	var wall=add(s,"wall",Vector2.ZERO)
	s.push_object(wall,Vector2(0,20),"cell",wall.p)
	check(is_zero_approx(s.physics.angular_velocity(wall)),"Central impulse produces no rotation")
	s.push_object(wall,Vector2(0,20),"cell",wall.p+Vector2(30,0))
	check(s.physics.angular_velocity(wall)>0 and wall.angle==0,"Off-centre impulse adds angular velocity")
	advance(s,0.1)
	check(wall.angle>0.01,"Angular velocity turns the wall over time")
	var angular=s.physics.angular_velocity(wall)
	advance(s,0.2)
	check(s.physics.angular_velocity(wall)<angular,"Angular damping settles spinning walls")
	s=setup()
	var mover=add(s,"tackle",Vector2.ZERO)
	s.physics.drive(mover,Vector2(100,0));s.physics.step(s,1.0/60)
	check(s.physics.velocity(mover).x>0 and s.physics.velocity(mover).x<100,"Motor accelerates instead of setting speed immediately")
	s.physics.drive(mover,Vector2(-100,0));s.physics.step(s,1.0/120)
	check(s.physics.velocity(mover).x<10,"Direction change applies braking")
	s=setup()
	var a=add(s,"seeker",Vector2(-18,0));var b=add(s,"seeker",Vector2(18,0))
	s.physics.impulse(s,a,Vector2(50,0),a.p)
	s.physics.step(s,1.0/120)
	check(s.physics.velocity(b).x>40 and absf(s.physics.velocity(a).x)<1,"Equal masses transfer collision momentum")
	check(s.physics.touching(a,b),"Physical contact remains available to old damage rules")
	s=setup();wall=add(s,"wall",Vector2.ZERO);wall.angle=PI/2
	a=add(s,"seeker",Vector2(29,30))
	check(not s.physics.collision(s,wall,a).is_empty(),"Rotated wall collides along actual side")
	a.p=Vector2(40,0)
	check(s.physics.collision(s,wall,a).is_empty(),"Rotated wall does not use unrotated rectangle")
	a.p=Vector2(29,30);s.physics.impulse(s,a,Vector2(-60,0),a.p)
	s.physics.step(s,1.0/120)
	check(absf(s.physics.angular_velocity(wall))>0.01,"Off-centre collision rotates wall")
	s=setup();a=add(s,"seeker",Vector2(-60,0));b=add(s,"bond",Vector2.ZERO)
	s.rebuild_links()
	b.p.x=40
	var length=a.p.distance_to(b.p)
	advance(s,0.1)
	check(a.p.distance_to(b.p)<length and a.p.distance_to(b.p)>s.links[0].rest,"Bond pulls elastically without rigid projection")
	s.begin_battle();s.spawn_queue.clear()
	s.push_object(a,Vector2(20,5),"cell",a.p)
	s.phase="recap";s.next_round()
	check(s.physics.states.is_empty() and a.p==a.start,"New preparation clears motion and restores placement")
	var blueprint=s.rules.duplicate(true)
	check(blueprint.contact_damage==1 and blueprint.max_battle_seconds==180 and s.catalog.size()==41,"F2 leaves damage, lifetimes and catalogue unchanged")
	s=setup()
	var virus={"id":900,"type":"basic","p":Vector2.ZERO,"alive":true,"freeze":1.0}
	s.viruses=[virus]
	s.physics.impulse(s,virus,Vector2(50,0),virus.p)
	advance(s,0.1)
	check(virus.p==Vector2.ZERO,"Existing tag freeze still stops virus drift")
	s=setup()
	for i in range(45):add(s,"wall" if i%5==0 else "seeker",Vector2((i%9)*65-260,(i/9)*60-120))
	var started=Time.get_ticks_msec()
	advance(s,0.5)
	var duration=Time.get_ticks_msec()-started
	print("BENCH: 45 bodies, 60 substeps: %d ms" % duration)
	check(s.cells.all(func(c):return c.p.is_finite() and is_finite(c.angle)),"Crowded body solver remains finite")
	s=setup();a=add(s,"seeker",Vector2.ZERO);b=add(s,"bond",Vector2(200,0))
	s.apply_tuning("seeker",{"physics/linear_damping":10,"physics/max_speed":40})
	s.physics.impulse(s,a,Vector2(100,0));s.physics.impulse(s,b,Vector2(100,0))
	advance(s,0.1)
	check(s.physics.velocity(a).x<20 and s.physics.velocity(b).x>90,"Per-type damping and speed cap affect motion without changing other types")
	s=setup();a=add(s,"seeker",Vector2(-18,0));b=add(s,"bond",Vector2(18,0))
	s.apply_tuning("seeker",{"physics/restitution":0})
	s.physics.impulse(s,a,Vector2(50,0));s.physics.step(s,1.0/120)
	check(absf(s.physics.velocity(a).x-s.physics.velocity(b).x)<1,"Edited restitution absorbs bounce in real contact")
	# MC-039: actual virus contact, not a manually supplied off-centre force.
	var edge_angles=[]
	for hit_x in [-32.0,0.0,32.0]:
		s=setup();wall=add(s,"wall",Vector2.ZERO)
		virus={"id":900,"type":"basic","p":Vector2(hit_x,22),"alive":true,"freeze":0.0}
		s.viruses=[virus]
		s.physics.state(virus).v=Vector2(0,-100)
		advance(s,0.2)
		edge_angles.append(wall.angle)
		check(wall.p.y < -1,"Virus contact visibly displaces wall at x=%s" % hit_x)
	check(edge_angles[0]>0.05 and edge_angles[2]<-0.05,"Opposite edge hits visibly rotate in opposite directions")
	check(absf(edge_angles[1])<0.001,"Central virus contact does not invent torque")
	s=setup();wall=add(s,"wall",Vector2.ZERO)
	virus={"id":900,"type":"basic","p":Vector2(32,22),"alive":true,"freeze":0.0}
	s.physics.state(virus).v=Vector2(0,-100)
	var hit=s.physics.collision(s,wall,virus)
	s.physics.solve_contact(s,wall,virus,hit)
	var momentum=s.physics.velocity(wall)*s.physics.mass(s,wall)+s.physics.velocity(virus)*s.physics.mass(s,virus)
	check(momentum.distance_to(Vector2(0,-100)*s.physics.mass(s,virus))<0.001,"Boosted impact preserves total linear momentum")
	var boosted=s.physics.velocity(wall).length()
	s.physics.clear();s.physics.state(virus).v=Vector2(0,-100)
	s.rules.body_physics.contact_impulse_scale=1.0
	s.physics.solve_contact(s,wall,virus,hit)
	check(is_equal_approx(boosted,s.physics.velocity(wall).length()*1.5),"Virus contact boost increases actual impulse by 50 percent")
	s=setup();a=add(s,"seeker",Vector2.ZERO)
	s.physics.drive(a,Vector2(20,0));s.physics.step(s,0.001)
	var initial_speed=s.physics.velocity(a).x
	s.physics.state(a).v=Vector2.ZERO
	s.apply_tuning("seeker",{"physics/density":2.0})
	s.physics.impulse(s,a,Vector2(2,0))
	check(is_equal_approx(s.physics.velocity(a).x,1.0),"Impulse immediately uses edited density outside a step")
	s.physics.state(a).v=Vector2.ZERO
	s.physics.drive(a,Vector2(20,0));s.physics.step(s,0.001)
	check(is_equal_approx(s.physics.velocity(a).x,initial_speed/2.0),"Next step immediately uses edited density, not cached material")
	var rng=RandomNumberGenerator.new();rng.seed=909
	var same_pairs=true
	for sample in range(50):
		var bodies=[]
		for i in range(80):
			var body={"p":Vector2(rng.randf_range(-400,400),rng.randf_range(-300,300)),"jump":i%11==0,"emerging":i%13==0}
			if i%3==0:body.key="wall"
			elif i%3==1:body.type="basic"
			bodies.append(body)
		if s.physics.candidate_pairs(bodies)!=reference_candidates(bodies):same_pairs=false
	check(same_pairs,"Spatial candidates retain exact pair order across mixed bodies, jumps and emergence")
	print("RESULT: %d checks, %d failures" % [checks,errors])
	quit(errors)
