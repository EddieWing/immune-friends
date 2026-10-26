extends RefCounted
# F2: impulse-based bodies with circle / oriented-box contacts.
# Current game geometry is retained. This is not a numerically identical Box2D port.
var states={}
var contacts={}
var drives={}
var settings={}
func clear():
	states.clear()
	contacts.clear()
	drives.clear()
func id_of(body):
	return int(body.id) if body.has("key") or body.has("type") else -2-int(body.id)
func state(body):
	var id=id_of(body)
	if not states.has(id): states[id]={"v":Vector2.ZERO,"w":0.0}
	return states[id]
func velocity(body):
	return state(body).v
func angular_velocity(body):
	return float(state(body).w)
func is_box(s,body):
	return body.has("key") and s.catalog[body.key].behavior=="wall"
func radius(body):
	return 18.0 if body.has("key") else (10.0 if body.has("type") else 13.0)
func tuning_key(body):
	return str(body.key) if body.has("key") else ("virus:"+str(body.type) if body.has("type") else "__core")
func parameter(s,body,field):
	var fallback=s.rules.body_physics.get(field,1.0)
	if field=="density":
		fallback=10.0 if tuning_key(body) in ["__core","mortar","seeker_factory","wildcard"] else (0.01 if tuning_key(body)=="kinetic_generator" else 1.0)
	return float(s.tuning.get(tuning_key(body),{}).get("physics/"+field,fallback))
func mass(s,body):
	var density=maxf(0.001,parameter(s,body,"density"))
	var area=86.0*26.0 if is_box(s,body) else PI*pow(radius(body),2)
	return density*area/(PI*18.0*18.0)
func inertia(s,body):
	return mass(s,body)*((86.0*86.0+26.0*26.0)/12.0 if is_box(s,body) else radius(body)*radius(body)*0.5)
func impulse(s,body,value,point=Vector2.INF):
	var st=state(body)
	st.v+=value/mass(s,body)
	if point!=Vector2.INF:
		st.w+=(point-body.p).cross(value)/inertia(s,body)
func drive(body,target):
	drives[id_of(body)]=target
func accelerate(s,body,force,delta):
	impulse(s,body,force*delta)
func touching(a,b):
	var x=id_of(a);var y=id_of(b)
	return contacts.has(Vector2i(mini(x,y),maxi(x,y)))
func axes(body):
	return [Vector2.RIGHT.rotated(float(body.get("angle",0))),Vector2.DOWN.rotated(float(body.get("angle",0)))]
func extent(s,body,axis):
	if not is_box(s,body): return radius(body)
	var basis=axes(body)
	return absf(axis.dot(basis[0]))*43.0+absf(axis.dot(basis[1]))*13.0
func support(s,body,axis):
	if not is_box(s,body): return body.p+axis*radius(body)
	var basis=axes(body)
	# Face centre for parallel directions, rather than an arbitrary corner.
	return body.p+basis[0]*43.0*signf(axis.dot(basis[0]))+basis[1]*13.0*signf(axis.dot(basis[1]))
func collision(s,a,b):
	var delta=b.p-a.p
	var a_box=is_box(s,a);var b_box=is_box(s,b)
	var ra=45.0 if a_box else radius(a)
	var rb=45.0 if b_box else radius(b)
	if delta.length_squared()>(ra+rb+0.02)*(ra+rb+0.02): return {}
	if not a_box and not b_box:
		var distance=delta.length()
		var depth=radius(a)+radius(b)-distance
		if depth < -0.02: return {}
		var normal=delta/distance if distance>0.0001 else Vector2.RIGHT
		return {"n":normal,"depth":maxf(0,depth),"p":a.p+normal*(radius(a)-depth*0.5)}
	if a_box and b_box:
		var normal=Vector2.RIGHT
		var depth=INF
		for axis in axes(a)+axes(b):
			var overlap=extent(s,a,axis)+extent(s,b,axis)-absf(delta.dot(axis))
			if overlap < -0.02:return {}
			if overlap<depth:
				depth=overlap
				normal=axis if delta.dot(axis)>=0 else -axis
		return {"n":normal,"depth":maxf(0,depth),"p":(support(s,a,normal)+support(s,b,-normal))*0.5}
	var box=a if a_box else b
	var ball=b if a_box else a
	var angle=float(box.get("angle",0))
	var local=(ball.p-box.p).rotated(-angle)
	var closest=local.clamp(Vector2(-43,-13),Vector2(43,13))
	var difference=local-closest
	var distance=difference.length()
	var normal=Vector2.RIGHT
	var depth=0.0
	if distance>0.0001:
		depth=radius(ball)-distance
		if depth < -0.02:return {}
		normal=difference/distance
	else:
		var dx=43-absf(local.x);var dy=13-absf(local.y)
		normal=Vector2(1 if local.x>=0 else -1,0) if dx<dy else Vector2(0,1 if local.y>=0 else -1)
		closest=local+normal*minf(dx,dy)
		depth=radius(ball)+minf(dx,dy)
	normal=normal.rotated(angle)
	return {"n":normal if a_box else -normal,"depth":maxf(0,depth),"p":box.p+closest.rotated(angle)}
func solve_contact(s,a,b,hit):
	var normal=hit.n
	var sa=state(a);var sb=state(b)
	var arm_a=hit.p-a.p;var arm_b=hit.p-b.p
	var va=sa.v+Vector2(-arm_a.y,arm_a.x)*sa.w
	var vb=sb.v+Vector2(-arm_b.y,arm_b.x)*sb.w
	var relative=(vb-va).dot(normal)
	if relative>=0 and hit.depth<=0.02:return
	var ima=1.0/mass(s,a);var imb=1.0/mass(s,b)
	if relative<0:
		var iia=1.0/inertia(s,a);var iib=1.0/inertia(s,b)
		var denom=ima+imb+pow(arm_a.cross(normal),2)*iia+pow(arm_b.cross(normal),2)*iib
		var bounce=minf(parameter(s,a,"restitution"),parameter(s,b,"restitution")) if relative < -2.0 else 0.0
		var value=normal*(-(1.0+bounce)*relative/denom)
		# Deliberate game-feel boost for approaching virus/cell impacts only.
		# Equal/opposite impulses retain momentum and the actual contact lever arm.
		if (a.has("type") and b.has("key")) or (b.has("type") and a.has("key")):
			value*=float(s.rules.body_physics.get("contact_impulse_scale",1.0))
		sa.v-=value*ima
		sa.w-=arm_a.cross(value)*iia
		sb.v+=value*imb
		sb.w+=arm_b.cross(value)*iib
	# Small mass-weighted overlap correction; momentum comes from the impulses above.
	var correction=normal*maxf(0,hit.depth-0.02)*0.65/(ima+imb)
	a.p-=correction*ima
	b.p+=correction*imb
func candidate_pairs(bodies):
	var grid={}
	var cell_grid={}
	for i in range(bodies.size()):
		var tile=Vector2i(floori(bodies[i].p.x/96.0),floori(bodies[i].p.y/96.0))
		if not grid.has(tile):grid[tile]=[]
		grid[tile].append(i)
		if bodies[i].has("key"):
			if not cell_grid.has(tile):cell_grid[tile]=[]
			cell_grid[tile].append(i)
	var pairs=[]
	for i in range(bodies.size()):
		var a=bodies[i]
		if a.get("jump",false) or a.get("emerging",false):continue
		var tile=Vector2i(floori(a.p.x/96.0),floori(a.p.y/96.0))
		# Virus/virus and core/virus pairs never participate in this solver.
		var candidates=grid if a.has("key") else cell_grid
		for y in range(-1,2):
			for x in range(-1,2):
				for j in candidates.get(tile+Vector2i(x,y),[]):
					if j<=i:continue
					var b=bodies[j]
					if b.get("jump",false) or b.get("emerging",false):continue
					if not a.has("key") and not b.has("key"):continue
					pairs.append(Vector2i(i,j))
	return pairs

func step(s,delta):
	if delta<=0:return
	settings=s.rules.body_physics
	contacts.clear()
	var bodies=[]
	for body in s.cells+s.viruses+s.blood:
		if body.alive: bodies.append(body)
	var live={}
	for body in bodies: live[id_of(body)]=true
	for id in states.keys():
		if not live.has(id): states.erase(id)
	for i in range(s.blood.size()):
		if s.blood[i].alive:state(s.blood[i]).v=s.blood_velocity.get(i,Vector2.ZERO)
	var steps=maxi(1,ceili(delta/float(settings.max_step)))
	var dt=delta/steps
	for tick in range(steps):
		# Existing elastic bonds retain their rest length and nearest-neighbour rules.
		for link in s.links:
			var a=s.endpoint_by_id(link.a);var b=s.endpoint_by_id(link.b)
			if a.is_empty() or b.is_empty() or not a.alive or not b.alive:continue
			var offset=b.p-a.p
			var length=offset.length()
			if length<0.001:continue
			var normal=offset/length
			var relative=(velocity(b)-velocity(a)).dot(normal)
			var stiffness=float(settings.spring_stiffness)
			var damping=float(settings.spring_damping)
			var arm_a=Vector2.RIGHT.rotated(float(a.get("angle",0)))*minf(25,extent(s,a,normal))
			var arm_b=Vector2.RIGHT.rotated(float(b.get("angle",0)))*minf(25,extent(s,b,-normal))
			var inverse_mass=1.0/mass(s,a)+1.0/mass(s,b)+pow(arm_a.cross(normal),2)/inertia(s,a)+pow(arm_b.cross(normal),2)/inertia(s,b)
			var force=normal*((length-link.rest)*stiffness+relative*damping)/(1.0+(damping*dt+stiffness*dt*dt)*inverse_mass)
			impulse(s,a,force*dt,a.p+arm_a)
			impulse(s,b,-force*dt,b.p-arm_b)
		for body in bodies:
			if not body.has("key") and not body.has("type"):continue # Blood retains its soft-body integrator until F5.
			if body.get("emerging",false):continue # Scripted birth animation remains outside F2.
			var st=state(body)
			# Preserve existing status / attachment rules; F2 does not redefine tags or Swarmer.
			if body.has("type") and (float(body.get("freeze",0))>0 or int(body.get("host",-1))>=0):
				st.v=Vector2.ZERO
				st.w=0.0
			var target=drives.get(id_of(body),Vector2.ZERO)
			if target.length_squared()>0:
				var force=(target-st.v)*parameter(s,body,"motor_response")
				force=force.limit_length(parameter(s,body,"motor_force"))
				st.v+=force/mass(s,body)*dt
			st.v*=exp(-parameter(s,body,"linear_damping")*dt)
			st.w*=exp(-parameter(s,body,"angular_damping")*dt)
			st.v=st.v.limit_length(parameter(s,body,"max_speed"))
			st.w=clampf(st.w,-parameter(s,body,"max_angular_speed"),parameter(s,body,"max_angular_speed"))
			body.p+=st.v*dt
			if body.has("key"):body.angle=wrapf(float(body.angle)+st.w*dt,-PI,PI)
			# Keep the established playfield boundary; reflect velocity, never store out-of-bounds momentum.
			if body.has("key"):
				var ex=extent(s,body,Vector2.RIGHT);var ey=extent(s,body,Vector2.DOWN)
				var clipped=body.p.clamp(Vector2(-620+ex,-365+ey),Vector2(620-ex,350-ey))
				if clipped.x!=body.p.x:st.v.x=-st.v.x*parameter(s,body,"restitution")
				if clipped.y!=body.p.y:st.v.y=-st.v.y*parameter(s,body,"restitution")
				body.p=clipped
		var pairs=candidate_pairs(bodies)
		for pass_no in range(3):
			for pair in pairs:
				var a=bodies[pair.x];var b=bodies[pair.y]
				var hit=collision(s,a,b)
				if hit.is_empty():continue
				var ia=id_of(a);var ib=id_of(b)
				contacts[Vector2i(mini(ia,ib),maxi(ia,ib))]=true
				solve_contact(s,a,b,hit)
	for i in range(s.blood.size()):
		if s.blood[i].alive:s.blood_velocity[i]=state(s.blood[i]).v
	drives.clear()
