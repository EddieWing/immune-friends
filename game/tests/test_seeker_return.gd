extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Motion=preload("res://scripts/seeker_motion.gd")
const Presentation=preload("res://scripts/support_presentation.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize():
	for key in ["seeker","tag_splitter","tag_proof"]:
		var sim=Sim.new();sim.reset(42,12);sim.gym_mode=true;sim.experimental=true
		var c=sim.make_cell(key,Vector2(1000,0));sim.cells=[c];sim.begin_battle();sim.spawn_queue=[]
		var target={"id":99,"p":Vector2(1400,0)}
		var layer=Presentation.new();layer.update(sim,0)
		check(c.seeker_home==Vector2(1000,0),key+": battle placement is home")
		check(Motion.direction(sim,c,target,1.0/60)==Vector2.RIGHT,key+": target pursuit unchanged")
		c.p=Vector2(1250,0)
		for i in range(65):Motion.direction(sim,c,{},1.0/60)
		check(c.seeker_direction==Vector2.RIGHT and not c.seeker_returning,key+": retain direction until timeout")
		check(not sim.events.any(func(e):return e.event=="cell_return"),key+": no early return signal")
		Motion.direction(sim,c,{},1.0/60);layer.update(sim,0)
		check(c.seeker_direction==Vector2.LEFT and c.seeker_returning,key+": return points to home at timeout")
		check(sim.events.filter(func(e):return e.event=="cell_return").size()==1,key+": one transition event")
		check(layer.effects.any(func(e):return e.kind=="cell_return"),key+": event produces cue")
		for i in range(10):Motion.direction(sim,c,{},1.0/60)
		check(sim.events.filter(func(e):return e.event=="cell_return").size()==1,key+": no repeated cue")
		Motion.direction(sim,c,target,1.0/60)
		sim.record("cell_target",{"id":c.id,"p":c.p,"target_id":99,"target":target.p});layer.update(sim,0)
		check(not c.seeker_returning and c.seeker_return_timer==1.1,key+": acquisition cancels return")
		check(not layer.effects.any(func(e):return e.kind=="cell_return"),key+": acquisition removes obsolete cue")
		c.p=c.seeker_home+Vector2(Motion.HOME_RADIUS-0.01,0)
		for i in range(70):Motion.direction(sim,c,{},1.0/60)
		check(c.seeker_direction==Vector2.ZERO and not c.seeker_returning,key+": home radius stops desired movement")
		var count=sim.events.filter(func(e):return e.event=="cell_return").size()
		c.p+=Vector2(100,0);Motion.direction(sim,c,{},1.0/60)
		check(c.seeker_returning and sim.events.filter(func(e):return e.event=="cell_return").size()==count,key+": late displacement follows original no-repeat marker rule")
		sim.phase="recap";sim.next_round();c.p=Vector2(200,200);sim.begin_battle()
		check(c.seeker_home==Vector2(200,200) and c.seeker_direction==Vector2.ZERO,key+": next run adopts new placement")
		# Physical integration: actual motor moves an isolated cell back home.
		c.p=Vector2(400,200);c.seeker_return_timer=0.01
		sim.spawn_queue=[];sim.viruses=[]
		var start_distance=c.p.distance_to(c.seeker_home)
		for i in range(180):sim.update(1.0/60)
		check(c.p.distance_to(c.seeker_home)<start_distance-50,key+": physical body moves home")
		check(c.p.distance_to(c.seeker_home)<Motion.HOME_RADIUS+3,key+": body settles in home radius")
	print("Seeker return: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
