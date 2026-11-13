extends "res://scripts/simulation.gd"
var native_core
func _init():
	super()
	native_core=ClassDB.instantiate("CoreKernel")
func step_blood_web(delta):
	var living=false
	for b: Dictionary in blood:
		if b.alive:living=true;break
	if not living:return
	var count=maxi(1,int(ceil(minf(delta,0.1)*120)))
	var dt: float=minf(delta,0.1)/count
	while web_core_normals.size()<blood.size():web_core_normals.append(Vector2.RIGHT.rotated(web_core_normals.size()*2.4))
	var rows=PackedFloat64Array();var edges=PackedInt32Array()
	rows.resize(blood.size()*7)
	for i in range(blood.size()):
		var b: Dictionary=blood[i];var velocity: Vector2=blood_velocity.get(i,Vector2.ZERO)
		rows[i*7]=b.p.x;rows[i*7+1]=b.p.y;rows[i*7+2]=1.0 if b.alive else 0.0
		rows[i*7+3]=velocity.x;rows[i*7+4]=velocity.y;rows[i*7+5]=web_core_normals[i].x;rows[i*7+6]=web_core_normals[i].y
	for link in blood_links:edges.append(link.a);edges.append(link.b)
	var rate=float(rules.blood_drift.speed)/maxf(1,float(rules.blood_drift.slow_radius))
	var result:PackedFloat32Array=native_core.step(rows,edges,count,dt,exp(-rate*dt)-1.0,float(rules.blood_elasticity.stiffness),exp(-float(rules.blood_elasticity.damping)*dt))
	for i in range(blood.size()):
		blood[i].p=Vector2(result[i*4],result[i*4+1])
		if blood[i].alive:blood_velocity[i]=Vector2(result[i*4+2],result[i*4+3])
