extends "res://scripts/simulation.gd"
func update_swarm_attraction(v,delta,_prepared={},_swarm_adj={}):
	var attached=[]
	for link in links:
		if not link.get("swarm",false):continue
		var other=link.b if link.a==v.id else (link.a if link.b==v.id else -1)
		var body=endpoint_by_id(other)
		if not body.is_empty() and body.alive:attached.append(body)
	var host=-1 if attached.is_empty() else attached[0].id
	if v.get("host",-1)!=host:
		record("virus_attachment",{"id":v.id,"p":v.p,"old_host":v.get("host",-1),"host":host})
	v.host=host
	if host!=-1 or v.freeze>0:return
	var nearby=viruses.filter(func(other):return other.alive and other.id!=v.id and not other.jump and v.p.distance_to(other.p)<60.0*26.0/3.5)
	nearby.sort_custom(func(a,b):return v.p.distance_squared_to(a.p)<v.p.distance_squared_to(b.p))
	for other in nearby.slice(0,9):
		physics.accelerate(self,v,v.p.direction_to(other.p)*25.0*virus_motion.multiplier(self,v)*preload("res://scripts/reference_physics.gd").MASS_UNIT,delta)

func join_swarm_contacts():
	for v in viruses:
		if not v.alive or v.type!="swarmer" or v.jump or v.get("host",-1)>=0:continue
		for other in viruses:
			if not other.alive or other==v or other.jump:continue
			if links.any(func(l):return (l.a==v.id and l.b==other.id) or (l.b==v.id and l.a==other.id)):continue
			if v.p.distance_to(other.p)>physics.radius(v)+physics.radius(other)+0.02:continue
			links.append({"a":v.id,"b":other.id,"owner":v.id,"rest":v.p.distance_to(other.p),"offset":(other.p-v.p).rotated(-float(v.get("angle",0))),"relative_angle":float(other.get("angle",0))-float(v.get("angle",0)),"locked":true,"swarm":true})
			record("virus_attachment",{"id":v.id,"p":v.p,"old_host":-1,"host":other.id})
			v.host=other.id
