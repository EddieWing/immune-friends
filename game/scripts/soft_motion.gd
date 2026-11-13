extends RefCounted
# Cosmetic, opt-in Gym preview. Never writes simulation or physics state.
var enabled=false
var ids=[]
var states={}
var observed_sim
var revision=-1
var elapsed=0.0
var phase=""

func active(id):
	return enabled and ids.has(id)

func update(sim,delta):
	if observed_sim!=sim or revision!=sim.presentation_revision or phase!=sim.phase or sim.elapsed<elapsed:
		states.clear()
		elapsed=sim.elapsed
	observed_sim=sim
	revision=sim.presentation_revision
	phase=sim.phase
	var dt=maxf(0,sim.elapsed-elapsed) if phase=="battle" else delta
	elapsed=sim.elapsed
	if not enabled: return
	var live={}
	for c in sim.cells:
		if not active(c.id) or not c.alive: continue
		live[c.id]=true
		if not states.has(c.id):
			states[c.id]={"p":c.p,"v":Vector2.ZERO,"face":Vector2.ZERO,"fv":Vector2.ZERO,"q":Vector2.ZERO,"qv":Vector2.ZERO}
		var s=states[c.id]
		if dt<=0: continue
		# Reading the dictionary avoids physics.velocity(), which creates missing states.
		var velocity=sim.physics.states.get(c.id,{}).get("v",Vector2.ZERO) if phase=="battle" else (c.p-s.p)/maxf(dt,0.001)
		if c.p.distance_to(s.p)>100 or dt>0.25:
			s.face=Vector2.ZERO; s.fv=Vector2.ZERO; s.q=Vector2.ZERO; s.qv=Vector2.ZERO
		else:
			var change=(velocity-s.v).limit_length(180)
			s.fv-=change*0.22
			if change.length()>2:
				var axis=change.angle()*2
				s.qv-=Vector2(cos(axis),sin(axis))*minf(change.length()*0.022,2.8)
			var steps=maxi(1,int(ceil(dt/0.008)))
			var h=dt/steps
			for i in range(steps):
				s.fv+=(-s.face*180-s.fv*19)*h
				s.face=(s.face+s.fv*h).limit_length(3.5)
				s.qv+=(-s.q*210-s.qv*17)*h
				s.q=(s.q+s.qv*h).limit_length(0.13)
			s.qv=s.qv.limit_length(4)
		# Always reset sampling origin, including teleports.
		s.p=c.p; s.v=velocity
	for id in states.keys():
		if not live.has(id): states.erase(id)

func face_offset(id):
	return states.get(id,{}).get("face",Vector2.ZERO) if active(id) else Vector2.ZERO

func body_transform(id,p,angle,scale_value):
	var base=Transform2D(angle,Vector2.ZERO).scaled_local(scale_value)
	if not active(id):
		base.origin=p
		return base
	var q=states.get(id,{}).get("q",Vector2.ZERO) if active(id) else Vector2.ZERO
	var strength=q.length()
	var axis=q.angle()*0.5
	var stretch=Transform2D(axis,Vector2.ZERO)*Transform2D(0,Vector2.ZERO).scaled_local(Vector2(exp(strength),exp(-strength)))*Transform2D(-axis,Vector2.ZERO)
	var result=stretch*base
	result.origin=p
	return result

func arm_points(start,end,bend):
	var points=PackedVector2Array()
	var normal=start.direction_to(end).orthogonal()
	for i in range(13):
		var t=i/12.0
		points.append(start.lerp(end,t)+normal*sin(PI*t)*bend)
	return points
