extends "res://scripts/workers/core_simulation.gd"
func _init():
	super()
	physics=preload("res://scripts/workers/worker_physics.gd").new()
	electricity=preload("res://scripts/workers/worker_electricity.gd").new()

func advance_projectiles_web(delta,movement_delta):
	var bodies=[];var packed=PackedFloat64Array()
	for body: Dictionary in cells+viruses:
		var kind=0 if body.has("type") else PROJECTILE_BODY_KIND.get(body.key,-1)
		if kind<0:continue
		bodies.append(body)
		var position: Vector2=body.p
		packed.append_array(PackedFloat64Array([position.x,position.y,body.id,float(body.alive),float(body.get("jump",false)),float(body.get("tag",0)),kind,float(physics.is_box(self,body)),float(body.get("angle",0)),physics.radius(body),physics.half_size(body).x,physics.half_size(body).y]))
	if not physics.local_ready:
		physics.local_core.local_init(preload("res://scripts/workers/web_kernel.gd").SOURCE)
		physics.local_ready=true
	var kernel=physics.local_core
	kernel.local_projectile_start(Marshalls.raw_to_base64(packed.to_byte_array()),pack_projectile_items(0),JSON.stringify([delta,movement_delta,experimental],"",true,true))
	var sent=particles.size();var changed=-1;var alive=0;var tag=0
	while true:
		var extra=pack_projectile_items(sent) if sent<particles.size() else ""
		sent=particles.size()
		var values=kernel.local_projectile_next(changed,alive,tag,extra,particles.size())
		if values.is_empty():break
		changed=-1
		for offset in range(0,values.size(),10):
			var p: Dictionary=particles[int(values[offset])]
			p.p=Vector2(values[offset+1],values[offset+2]);p.v=Vector2(values[offset+3],values[offset+4]);p.life=values[offset+5]
			var target_index=int(values[offset+8])
			if target_index<0:continue
			var target: Dictionary=bodies[target_index]
			var from=Vector2(values[offset+6],values[offset+7])
			if p.kind=="bullet":apply_bullet_hit(p,from,p.p,target,values[offset+9])
			else:proteins.apply_tag_hit(self,p,from,p.p,target,values[offset+9])
			changed=target_index;alive=int(target.alive);tag=int(float(target.get("tag",0))>0)




func nearest_cores_batch(v: PackedVector2Array,c: PackedVector2Array,a: PackedInt32Array) -> PackedInt32Array:
	return physics.local_core.nearest_cores(v,c,a)

func supports_batched_cores() -> bool:
	return true
