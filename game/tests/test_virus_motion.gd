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
	quit(errors)
