extends RefCounted
# This entire extension is gated per run. Numerical gaps are explicit assumptions.
func tick(s,c,delta):
	var previous=Vector2(float(c.get("travel_x",c.p.x)),float(c.get("travel_y",c.p.y)))
	var travelled=previous.distance_to(c.p)
	c["travel_x"]=c.p.x
	c["travel_y"]=c.p.y
	if s.phase!="battle":return
	if c.key=="kinetic_bond":
		c["distance_health"]=float(c.get("distance_health",0))+travelled
		var threshold=s.constant_of(c,"distance",20)*float(s.rules.scale)
		if c.distance_health>threshold:
			c.distance_health-=threshold
			for id in s.ability_targets(c):
				var recipient=s.cell_by_id(id)
				if not recipient.is_empty():s.heal(recipient,s.constant_of(c,"healthIncrement",1),c)
	if not s.experimental:return
	if c.key=="kinetic_generator":
		c["distance_charge"]=float(c.get("distance_charge",0))+travelled
		var count=floori(c.distance_charge/(s.constant_of(c,"distance",12)*s.rules.scale))
		c.charge+=count*int(s.constant_of(c,"kineticIncrement",1))
		c.distance_charge-=count*s.constant_of(c,"distance",12)*s.rules.scale
	if c.key=="electromagnet":
		for v in s.viruses:
			if v.alive and v.p.distance_to(c.p)<s.range_of(c): s.physics.accelerate(s,v,v.p.direction_to(c.p)*60*float(s.rules.movement_multiplier),delta)

func feed_target(s,c):
	if not s.experimental: return {}
	var result={}
	var distance=s.range_of(c)
	for factory in s.cells:
		if factory.key!="seeker_factory" or not factory.alive or factory.get("bullet_food",0)>=2: continue
		var d=c.p.distance_to(factory.p)
		if d>=distance: continue
		if c.key=="sniper" and absf(Vector2.RIGHT.rotated(c.angle).angle_to(factory.p-c.p))>=0.20: continue
		result=factory
		distance=d
	return result

func virus_death(s,v):
	if not s.experimental or v.type!="pusher": return
	s.start_blast(v.p,6.0*float(s.rules.scale),0.0,400.0,v.id,true)

func electric_contacts(s,c,delta):
	if not c.alive:return
	var touching=[]
	for other in s.cells+s.viruses:
		if other.id!=c.id and other.alive and not other.get("jump",false) and s.physics.touching(c,other):touching.append(other.id)
	var timers=c.get("electric_targets",{})
	for id in timers.keys():
		if not touching.has(id):
			timers[id]-=delta
			if timers[id]<=0:timers.erase(id)
	c.electric_targets=timers
	c.electric_cool=maxf(0,float(c.get("electric_cool",0))-delta)
	if c.electric_cool>0:return
	for id in touching:
		if timers.has(id):continue
		timers[id]=0.25;c.electric_cool=0.1
		c.charge+=int(s.constant_of(c,"chargeIncrement",1))
		s.record("charge_generated",{"id":c.id,"p":c.p,"target":id})
