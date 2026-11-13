extends RefCounted
# Reference Auto Immune Demo 1.0.0 movement, converted by Core diameter 26 / 3.5.
const Ref=preload("res://scripts/reference_physics.gd")
const WORLD_SCALE=26.0/3.5
const REFERENCE_MASS=PI # Virus diameter 24 px / 12 px per metre = 2 m; density 1.
const SPEEDS={"basic":15.0,"hungry":15.0,"pusher":15.0,"swarmer":15.0,"avoider":20.0,"seeker":25.0,"jumper":5.0}
func multiplier(s,v):
	return float(s.rules.virus_speed)/15.0*float(s.rules.virus_movement_multiplier)*float(s.tuning.get("virus:"+v.type,{}).get("speed_multiplier",1.0))
# Shared only inside one steering pass; debug/tuning changes are seen next tick.
func context(s,v):
	var speed=float(s.rules.virus_speed)
	speed*=float(s.rules.get("virus_movement_multiplier",1.0))
	speed*=float(s.tuning.get("virus:"+v.type,{}).get("speed_multiplier",1.0))
	return {"speed":speed,"scale":multiplier(s,v),"mass":s.physics.mass(s,v)}
func tick(s,v,dir,delta,prepared={}):
	if prepared.is_empty():prepared=context(s,v)
	var scale=prepared.scale
	var body_mass=prepared.mass
	if v.type=="wave":
		if not v.has("wave_direction"):v.wave_direction=dir
		dir=v.wave_direction
		var progress=float(v.get("wave_progress",0))
		var side=1.0 if progress>-0.5 else -1.0
		var force=(dir+dir.orthogonal()*side*5.0)*37.5*scale*Ref.MASS_UNIT
		if v.freeze<=0:apply_impulse(s,v,force*delta,body_mass)
		progress+=delta
		if progress>0.5:progress-=2.0
		v.wave_progress=progress;v.visual_heading=dir
		return true
	if v.type=="jumper":
		if v.jump:
			v["jump_remaining"]=float(v.get("jump_remaining",0.1))-delta
			if v.jump_remaining<=0:
				apply_impulse(s,v,-dir*250.0*scale*Ref.MASS_UNIT,body_mass)
				v.jump=false;v.jump_cooldown=1.0
		else:
			v["jump_cooldown"]=float(v.get("jump_cooldown",1.0))-delta
			if v.jump_cooldown<=0:
				v.jump=true;v.jump_remaining=0.1
				if v.freeze<=0:apply_impulse(s,v,dir*250.0*scale*Ref.MASS_UNIT,body_mass)
		continuous(s,v,dir,delta,5.0*scale,16.0*scale)
		v.visual_heading=dir
		return true
	continuous(s,v,dir,delta,float(SPEEDS.get(v.type,15.0))*scale,(250.0 if v.type=="seeker" else 16.0)*scale)
	return true

# Reference motor applies constant acceleration; above the limit only lateral force remains.
func continuous(s,v,dir,delta,limit,acceleration):
	if v.freeze>0:return
	var body_state: Dictionary=s.physics.state(v)
	var velocity: Vector2=body_state.v
	var change: Vector2=dir*acceleration*delta
	if (velocity+change).length()>=limit:
		var axis=velocity.normalized()
		change-=axis*change.dot(axis)
	body_state.v+=change

func apply_impulse(s,v,value,body_mass):
	var body_state=s.physics.state(v)
	body_state.v+=value/body_mass

func speed_label(s,kind):
	if kind=="wave":return "wave"
	var value=snappedf(float(SPEEDS.get(kind,15.0))*multiplier(s,{"type":kind}),0.1)
	return str(value)+( " + jump" if kind=="jumper" else "")

