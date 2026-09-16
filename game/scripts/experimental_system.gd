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
		var count=floori(c.distance_charge/(12.0*s.rules.scale))
		c.charge+=count
		c.distance_charge-=count*12.0*s.rules.scale
	if travelled>0:
		for id in s.network(c.id):
			var provider=s.cell_by_id(id)
			if provider.get("key","")=="kinetic_bond" and provider.alive:
				c["distance_health"]=float(c.get("distance_health",0))+travelled
				var count=floori(c.distance_health/float(s.rules.kinetic_hp_distance))
				if count>0: s.heal(c,count,provider)
				c.distance_health-=count*float(s.rules.kinetic_hp_distance)
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
				c.charge+=1
				c.electric_cool=0.1
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
			if v.alive and v.p.distance_to(c.p)<s.range_of(c): v.p+=v.p.direction_to(c.p)*60*delta*float(s.rules.movement_multiplier)
	if c.key in ["seeker_factory","hungry_bomb"]:
		for p in s.particles:
			if p.life<=0 or p.p.distance_to(c.p)>float(s.rules.recipe_reach): continue
			if p.kind=="food":
				p.life=0
				c.food+=1
			elif p.kind=="bullet" and c.key=="seeker_factory" and c.get("bullet_food",0)<2:
				p.life=0
				c["bullet_food"]=int(c.get("bullet_food",0))+1
		if c.key=="hungry_bomb" and c.food>0:
			c["radius_growth"]=float(c.get("radius_growth",0))+c.food*float(s.rules.hungry_bomb_growth)
			c.food=0
		while c.key=="seeker_factory" and c.food>=1 and c.get("bullet_food",0)>=2:
			c.food-=1
			c.bullet_food-=2
			var baby=s.make_cell("seeker",c.p+Vector2.RIGHT.rotated(c.angle)*40)
			baby["temporary"]=true
			s.pending_cells.append(baby)
			s.record("produced",{"id":c.id,"p":c.p,"key":"seeker"})

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
	for c in s.cells:
		if c.alive and c.p.distance_to(v.p)<float(s.rules.pusher_virus_range):
			s.push_object(c,v.p.direction_to(c.p)*30,"cell",v.p)
