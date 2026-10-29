extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12)
	s.spawn_virus({"type":"wave","lane":0,"p":Vector2.ZERO});var v=s.viruses[0]
	s.virus_motion.tick(s,v,Vector2.RIGHT,0.01)
	var first=s.physics.velocity(v).y
	v.wave_progress=-1.0;s.physics.state(v).v=Vector2.ZERO
	s.virus_motion.tick(s,v,Vector2.DOWN,0.01)
	check(first*s.physics.velocity(v).y<0 and v.wave_direction==Vector2.RIGHT,"MC-027: Wave alternates lateral force while keeping initial aim")
	s.spawn_virus({"type":"jumper","lane":0,"p":Vector2.ZERO});v=s.viruses[1]
	for i in range(59):s.virus_motion.tick(s,v,Vector2.RIGHT,1.0/60)
	check(not v.jump,"MC-027: Jumper waits one second")
	s.virus_motion.tick(s,v,Vector2.RIGHT,1.0/60)
	check(v.jump and s.physics.velocity(v).x>0,"MC-027: jump starts with impulse")
	for i in range(7):s.virus_motion.tick(s,v,Vector2.RIGHT,1.0/60)
	check(not v.jump and v.jump_cooldown>0.9,"MC-027: short jump ends and cooldown restarts")
	s=Sim.new();s.reset(42,12);s.gym_mode=true;s.begin_battle();s.spawn_queue=[]
	var cell=s.make_cell("turret",Vector2(600,0));cell.cool=100;s.cells=[cell]
	s.spawn_virus({"type":"seeker","lane":0,"p":Vector2(500,0)});v=s.viruses[0]
	s.update(1.0/60)
	check(v.visual_target=="cell:"+str(cell.id),"MC-028: Seeker detects immune cell inside reference radius")
	cell.p=Vector2(800,0);s.update(1.0/60)
	check(v.visual_target.begins_with("core:"),"MC-028: Seeker outside range returns to baseline target")
	s.spawn_virus({"type":"avoider","lane":0,"p":Vector2(500,80)});v=s.viruses.back()
	cell.p=Vector2(500,130);s.physics.state(v).v=Vector2(30,0)
	s.update(1.0/60)
	check(v.visual_avoiding and s.physics.velocity(v).x!=0 and s.physics.velocity(v).y<0,"MC-028: Avoider adds repulsion without erasing inertia")
	quit(errors)
