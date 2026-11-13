extends "res://scripts/body_physics.gd"
var local_core
var local_ready=false
func _init():
	super()
	local_core=ClassDB.instantiate("CoreKernel")
	web_kernel=local_core # Worker-local implementation supplies the accelerated path.
func advance_web(s,bodies: Array,delta: float,steps: int):
	# Empty fields have no rows to encode; Godot rejects empty raw_to_base64 buffers.
	if bodies.is_empty():return
	if not local_ready:
		local_core.local_init(preload("res://scripts/workers/web_kernel.gd").SOURCE)
		local_ready=true
	# Compute libm coefficients in Godot once per material, retaining Float64.
	var dt=delta/steps
	if dt!=web_template_dt:
		web_template_dt=dt
		web_templates.clear();web_materials.clear();web_material_ids.clear();web_materials_dirty=true
	var rows=PackedFloat64Array()
	var body_states: Array[Dictionary]=[]
	var indices={}
	for body: Dictionary in bodies:
		# Prepare new material rows in the same pass as dynamic body values.
		# step() invalidates these caches for tuning edits; dt changes above also
		# invalidate the Godot-computed damping coefficients.
		var key: String=material_key(body)
		if not web_templates.has(key):
			var m: Dictionary=material_cache[key]
			m.linear_decay=1.0/(1.0+float(m.linear_damping)*dt)
			m.angular_decay=1.0/(1.0+float(m.angular_damping)*dt)
			var cell: bool=body.has("key");var virus: bool=body.has("type")
			web_templates[key]=PackedFloat64Array([0,0,0,0,0,radius(body),float(is_box(s,body)),float(cell),float(virus),1.0/m.mass,1.0/m.inertia,m.restitution,0,1,0,1,0,0,0,0,0,m.motor_response,m.motor_force,m.mass,m.linear_damping,m.angular_damping,m.max_speed,m.max_angular_speed,m.inertia,m.linear_decay,m.angular_decay,half_size(body).x,half_size(body).y])
			web_material_ids[key]=web_materials.size()
			web_materials.append(Array(web_templates[key]))
			web_materials_dirty=true
		var id: int=id_of(body)
		if not states.has(id):states[id]={"v":Vector2.ZERO,"w":0.0}
		var st: Dictionary=states[id]
		var p: Vector2=body.p;var v: Vector2=st.v
		var angle: float=body.get("angle",0)
		var target: Vector2=drives.get(id,Vector2.ZERO)
		indices[id]=body_states.size()
		body_states.append(st)
		rows.append_array(PackedFloat64Array([p.x,p.y,v.x,v.y,st.w,id,angle,target.x,target.y,float(not body.get("jump",false) and not body.get("emerging",false)),float(body.get("emerging",false)),float(float(body.get("freeze",0))>0),web_material_ids[key]]))
	if web_materials_dirty:
		local_core.local_materials(JSON.stringify(web_materials,"",true,true))
		web_materials_dirty=false
	var links=[]
	for link in s.links:
		if link.get("locked",false):continue
		var a=s.endpoint_by_id(link.a);var b=s.endpoint_by_id(link.b)
		if a.is_empty() or b.is_empty() or not a.alive or not b.alive:continue
		links.append([indices[id_of(a)],indices[id_of(b)],link.rest])
	var result=local_core.local_advance(rows,JSON.stringify([delta,steps,float(settings.get("contact_impulse_scale",1.0)),float(settings.spring_stiffness),float(settings.spring_damping),rigid_membership,s.phase!="battle"],"",true,true),JSON.stringify(links,"",true,true))
	for i in range(bodies.size()):
		var offset=i*6;var body: Dictionary=bodies[i]
		body.p=Vector2(result[offset],result[offset+1])
		var st: Dictionary=body_states[i];st.v=Vector2(result[offset+2],result[offset+3]);st.w=result[offset+4]
		if body.has("key"):body.angle=result[offset+5]
	for i in range(bodies.size()*6,result.size(),2):contacts[Vector2i(result[i],result[i+1])]=true
