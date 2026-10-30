extends RefCounted
# This entire extension is gated per run. Numerical gaps are explicit assumptions.
func tick(s,c,delta):
	if not s.experimental: return
	var previous=Vector2(float(c.get("travel_x",c.p.x)),float(c.get("travel_y",c.p.y)))
	var travelled=previous.distance_to(c.p)
	c["travel_x"]=c.p.x
	c["travel_y"]=c.p.y
	if c.key=="kinetic_generator":
		c["distance_charge"]=float(c.get("distance_charge",0))+travelled
		var count=floori(c.distance_charge/(s.constant_of(c,"distance",12)*s.rules.scale))
		c.charge+=count*int(s.constant_of(c,"kineticIncrement",1))
		c.distance_charge-=count*s.constant_of(c,"distance",12)*s.rules.scale
	if travelled>0:
		for id in s.network(c.id):
			var provider=s.cell_by_id(id)
			if provider.get("key","")=="kinetic_bond" and provider.alive:
				c["distance_health"]=float(c.get("distance_health",0))+travelled
				var count=floori(c.distance_health/(s.constant_of(provider,"distance",20)*float(s.rules.scale)))
				if count>0: s.heal(c,count*s.constant_of(provider,"healthIncrement",1),provider)
				c.distance_health-=count*s.constant_of(provider,"distance",20)*float(s.rules.scale)
				break
	if c.key=="electric_wall":
		c["electric_cool"]=maxf(0,float(c.get("electric_cool",0))-delta)
		if c.electric_cool<=0:
			var touching=false
			for other in s.cells:
				if other.id!=c.id and other.alive and s.contains_cell(c,other.p,18): touching=true
			for v in s.viruses:
				if v.alive and s.contains_cell(c,v.p,12): touching=true
			if touching:
				c.charge+=int(s.constant_of(c,"chargeIncrement",1))
				c.electric_cool=s.interval_of(c)
	if c.key=="electromagnet":
		c["magnet_cool"]=maxf(0,float(c.get("magnet_cool",0))-delta)
		if s.nearest_virus(c.p,s.range_of(c)).is_empty() and c.magnet_cool<=0:
			for other in s.cells:
				if other.id!=c.id and other.alive and other.charge>0 and other.p.distance_to(c.p)<float(s.rules.charge_range):
					other.charge-=1
					c.charge+=1
					c.magnet_cool=0.1
					break
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
