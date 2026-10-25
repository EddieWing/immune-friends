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
	print("RESULT: %d checks, %d failures" % [checks,errors])
	quit(errors)
