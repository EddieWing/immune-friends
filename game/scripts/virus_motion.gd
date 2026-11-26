extends RefCounted
# Reference rhythms; velocity adapter preserves the game's explicit 2x virus balance.
func multiplier(s,v):
	return float(s.rules.virus_speed)/15.0*float(s.rules.virus_movement_multiplier)*float(s.rules.movement_multiplier)*float(s.tuning.get("virus:"+v.type,{}).get("speed_multiplier",1.0))
# Shared only inside one steering pass; debug/tuning changes are seen next tick.
func context(s,v):
	var speed=float(s.rules.virus_speed)
	speed*=float(s.rules.get("virus_movement_multiplier",1.0))
	speed*=float(s.tuning.get("virus:"+v.type,{}).get("speed_multiplier",1.0))
	return {"speed":speed,"scale":multiplier(s,v),"mass":s.physics.mass(s,v)}
func tick(s,v,dir,delta,prepared={}):
	if v.type!="wave" and v.type!="jumper":return false
	if prepared.is_empty():prepared=context(s,v)
	var scale=prepared.scale
	var body_mass=prepared.mass
	if v.type=="wave":
		if not v.has("wave_direction"):v.wave_direction=dir
		dir=v.wave_direction
		var progress=float(v.get("wave_progress",0))
		var side=1.0 if progress>-0.5 else -1.0
		var force=(dir+dir.orthogonal()*side*5.0)*37.5*scale/(PI*1.75*1.75)*body_mass
		if v.freeze<=0:apply_impulse(s,v,force*delta,body_mass)
		progress+=delta
		if progress>0.5:progress-=2.0
		v.wave_progress=progress;v.visual_heading=dir
		return true
	if v.type=="jumper":
		if v.jump:
			v["jump_remaining"]=float(v.get("jump_remaining",0.1))-delta
			if v.jump_remaining<=0:
				apply_impulse(s,v,-dir*250.0*scale/(PI*1.75*1.75)*body_mass,body_mass)
				v.jump=false;v.jump_cooldown=1.0
				s.record("virus_landed",{"id":v.id,"p":v.p})
		else:
			v["jump_cooldown"]=float(v.get("jump_cooldown",1.0))-delta
			if v.jump_cooldown<=0:
				v.jump=true;v.jump_remaining=0.1
				s.record("virus_jump_started",{"id":v.id,"p":v.p})
				if v.freeze<=0:apply_impulse(s,v,dir*250.0*scale/(PI*1.75*1.75)*body_mass,body_mass)
		if v.freeze<=0 and not v.jump:s.physics.drive(v,dir*5.0*scale)
		v.visual_heading=dir
		return true
	return false

func apply_impulse(s,v,value,body_mass):
	var body_state=s.physics.state(v)
	body_state.v+=value/body_mass
