extends "res://scripts/simulation.gd"
# Regression oracle: the attraction loop before packed sorting, commit 6c5da42.
# Keep its full comparator sort: equal-distance force order is intentional.
func update_swarm_attraction(v,delta,_prepared={},_swarm_adj={}):
	var attached=[]
	for link in links:
		if not link.get("swarm",false):continue
		var other=link.b if link.a==v.id else (link.a if link.b==v.id else -1)
		if other==-1:continue
		var body=endpoint_by_id(other)
		if not body.is_empty() and body.alive:attached.append(body)
	var host=-1 if attached.is_empty() else attached[0].id
	if v.get("host",-1)!=host:
		record("virus_attachment",{"id":v.id,"p":v.p,"old_host":v.get("host",-1),"host":host})
	v.host=host
	if host!=-1 or v.freeze>0:return
	var nearby=[]
	for other: Dictionary in viruses:
		if not other.alive or other.id==v.id or other.jump:continue
		var offset: Vector2=v.p-other.p
		if offset.length()<60.0*26.0/3.5:nearby.append([offset.length_squared(),other])
	# Keep the same full sort and strict comparison (including equal-distance
	# ordering), but calculate each distance once instead of in every comparison.
	nearby.sort_custom(func(a,b):return a[0]<b[0])
	if nearby.is_empty():return
	# All nine attractions use the same material and movement tuning. Preserve
	# each Vector2 multiply/divide and impulse order, but resolve them once.
	var movement_scale=virus_motion.multiplier(self,v)
	var body_mass=physics.mass(self,v)
	var body_state=physics.state(v)
	for entry in nearby.slice(0,9):
		var other: Dictionary=entry[1]
		var force: Vector2=v.p.direction_to(other.p)*25.0*movement_scale*preload("res://scripts/reference_physics.gd").MASS_UNIT
		body_state.v+=force*delta/body_mass
