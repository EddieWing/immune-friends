extends SceneTree
const Sim=preload("res://scripts/simulation.gd")

# Pre-optimization oracle: full array scan and its original mutation order.
func legacy_join(s):
	for v in s.viruses:
		if not v.alive or v.type!="swarmer" or v.jump or v.get("host",-1)>=0:continue
		for other in s.viruses:
			if not other.alive or other==v or other.jump:continue
			if v.p.distance_to(other.p)>s.physics.radius(v)+s.physics.radius(other)+0.02:continue
			if s.links.any(func(l):return (l.a==v.id and l.b==other.id) or (l.b==v.id and l.a==other.id)):continue
			s.links.append({"a":v.id,"b":other.id,"owner":v.id,"rest":v.p.distance_to(other.p),"offset":(other.p-v.p).rotated(-float(v.get("angle",0))),"relative_angle":float(other.get("angle",0))-float(v.get("angle",0)),"locked":true,"swarm":true})
			s.record("virus_attachment",{"id":v.id,"p":v.p,"old_host":-1,"host":other.id})
			v.host=other.id

func _initialize():
	var a=Sim.new();var b=Sim.new();a.reset(42,12);b.reset(42,12)
	var rng=RandomNumberGenerator.new();rng.seed=51379
	for sample in range(512):
		var bodies=[]
		var extent=24.0 if sample%4==0 else 800.0
		for i in range(sample%81):
			var p=Vector2(rng.randf_range(-extent,extent),rng.randf_range(-extent,extent))
			if sample%4==1:p=Vector2((i%9-4)*32.0,(i/9-4)*32.0)+Vector2(0.001,-0.001)
			bodies.append({"id":i+100,"type":"swarmer" if i%3==0 and sample%7!=0 else "basic","alive":i%17!=7,"jump":i%13==8,"emerging":i%11==2,"host":101 if i%19==10 else -1,"p":p,"angle":rng.randf_range(-PI,PI)})
		if bodies.size()>=4 and sample%4==2:
			bodies[0].p=Vector2(-32.001,31.999);bodies[0].type="swarmer"
			bodies[1].p=bodies[0].p+Vector2(20.0199,0)
			bodies[2].p=bodies[0].p+Vector2(20.0201,0)
			bodies[3].p=bodies[0].p+Vector2(0,-19)
		var existing=[]
		if bodies.size()>=2 and sample%5==0:existing.append({"a":bodies[0].id,"b":bodies[1].id,"owner":bodies[0].id,"rest":19.0,"locked":true,"swarm":true})
		for sim in [a,b]:
			sim.viruses=bodies.duplicate(true);sim.links=existing.duplicate(true)
			sim.events.clear();sim.event_sequence=0
		a.join_swarm_contacts();legacy_join(b)
		if a.viruses!=b.viruses or a.links!=b.links or a.events!=b.events or a.event_sequence!=b.event_sequence:
			push_error("Swarm contact grid differs at sample "+str(sample));quit(1);return
		# A second pass must keep the same host filtering and duplicate-link rules.
		a.join_swarm_contacts();legacy_join(b)
		if a.viruses!=b.viruses or a.links!=b.links or a.events!=b.events:
			push_error("Repeated swarm contact differs at sample "+str(sample));quit(1);return
	print("PASS: 512 scenes / 1024 contact passes: sparse, dense, negative/tile boundaries, contact threshold, death, jump, emergence, existing links, host and event order")
	quit()
