extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Previous=preload("res://tests/fixtures/virus_motion_previous.gd")
var failures=0
var checks=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize():
	for type in ["wave","jumper"]:
		var a=Sim.new();var b=Sim.new()
		for s in [a,b]:
			s.reset(73,12)
			s.spawn_virus({"type":type,"lane":0,"p":Vector2(57,92)})
		var old=Previous.new()
		for tick in range(240):
			for s in [a,b]:
				if tick%13==0:
					s.tuning["virus:"+type]={"speed_multiplier":0.5+(tick%7)*0.2,"physics/density":0.01+(tick%11)}
					s.rules.virus_speed=12.0+(tick%5)
					s.rules.movement_multiplier=0.4+(tick%4)*0.7
					s.rules.virus_movement_multiplier=0.9+(tick%3)*0.3
				if tick%17==0:s.viruses[0].freeze=1.0
				if tick%19==0:s.viruses[0].freeze=0.0
				if tick==170:s.physics.clear()
			var direction=Vector2.from_angle(tick*0.17)
			var dt=1.0/60 if tick%3 else 0.04
			var settings=a.virus_motion.context(a,a.viruses[0])
			check(settings.mass==a.physics.mass(a,a.viruses[0]),"Prepared mass must follow live tuning")
			a.virus_motion.tick(a,a.viruses[0],direction,dt,settings)
			old.tick(b,b.viruses[0],direction,dt)
			check(a.viruses==b.viruses and a.physics.states==b.physics.states and a.physics.drives==b.physics.drives,"Wave/Jumper impulse or timers changed at %s %d"%[type,tick])
	print("RESULT: %d movement context checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
