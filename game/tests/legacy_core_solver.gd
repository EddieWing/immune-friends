# Frozen pre-0.2.26 solver: exact regression oracle, never loaded by the game.
extends "res://scripts/simulation.gd"
func step_blood(delta):
	var count=maxi(1,int(ceil(minf(delta,0.1)*120)))
	var dt=minf(delta,0.1)/count
	var config=rules.blood_elasticity
	for step in range(count):
		# Translate the living cluster uniformly: centering must not compress its springs.
		if blood_drag<0:
			var center=Vector2.ZERO
			var living=0
			for b in blood:
				if b.alive: center+=b.p; living+=1
			if living>0:
				center/=living
				var drift=rules.blood_drift
				var rate=float(drift.speed)/maxf(1,float(drift.slow_radius))
				var offset=center*(exp(-rate*dt)-1.0)
				for b in blood:
					if b.alive: b.p+=offset
		var forces={}
		for i in range(blood.size()): forces[i]=Vector2.ZERO
		for link in blood_links:
			var a=blood[link.a]
			var b=blood[link.b]
			if a.is_empty() or b.is_empty() or not a.alive or not b.alive: continue
			var offset=b.p-a.p
			var distance=offset.length()
			if distance<0.001: continue
			var force=offset/distance*(distance-26.0)*float(config.stiffness)
			forces[int(link.a)]+=force
			forces[int(link.b)]-=force
		for i in range(blood.size()):
			if not blood[i].alive: continue
			var velocity=blood_velocity.get(i,Vector2.ZERO)
			velocity=(velocity+forces[i]*dt)*exp(-float(config.damping)*dt)
			velocity=velocity.limit_length(650)
			if i==blood_drag:
				var next=blood[i].p.move_toward(blood_target,650*dt)
				velocity=(next-blood[i].p)/maxf(dt,0.00001)
			blood[i].p=(blood[i].p+velocity*dt).clamp(Vector2(-550,-300),Vector2(550,280))
			blood_velocity[i]=velocity
		for iteration in range(8):
			for i in range(blood.size()):
				if not blood[i].alive: continue
				for j in range(i+1,blood.size()):
					if not blood[j].alive: continue
					var offset=blood[j].p-blood[i].p
					var distance=offset.length()
					if distance>=26: continue
					var normal=offset/distance if distance>0.001 else Vector2.RIGHT.rotated(i*2.4)
					var wa=0.0 if i==blood_drag else 1.0
					var wb=0.0 if j==blood_drag else 1.0
					var correction=normal*(26-distance)/(wa+wb)
					blood[i].p-=correction*wa
					blood[j].p+=correction*wb
