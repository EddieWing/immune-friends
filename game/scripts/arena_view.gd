extends Node2D
const SIMPLE_VIRUS_EYES=preload("res://assets/ui/virus-field-eyes.svg")
const SIMPLE_VIRUS_BODY=preload("res://assets/ui/virus-field-body.svg")
const SIMPLE_CORE_BODIES=preload("res://assets/ui/core-field-bodies.svg")
const CORE_FACE_PARTS=preload("res://assets/ui/core-face-parts.svg")
const CLASSIC_CORE_BODIES=preload("res://assets/ui/core-classic-bodies.svg")
var virus_health=[]
var effect_strokes=preload("res://scripts/stroke_cache.gd").new()
const CELL_FACE_PARTS=preload("res://assets/ui/cell-face-parts.svg")
var wall_skins={}
var hair_roots=PackedVector2Array()
var hair_tips=PackedVector2Array()
var hair_tangents=PackedVector2Array()
func _init():
	for i in range(30):
		var normal=Vector2.from_angle(i*TAU/30.0)
		hair_roots.append(normal*10.7)
		hair_tips.append(normal*13.0)
		hair_tangents.append(normal.orthogonal())
var new_field=false
var new_hud=false
var sim
var optical_intensity=1.0
var flash_intensity=1.0
var microscope_effects=preload("res://scripts/microscope_effects.gd").new()
var attention=preload("res://scripts/attention_presentation.gd").new()
var support=preload("res://scripts/support_presentation.gd").new()
var virus_behavior=preload("res://scripts/virus_behavior_presentation.gd").new()
var reactions=preload("res://scripts/reaction_presentation.gd").new()
var sources=preload("res://scripts/source_presentation.gd").new()
var attacks=preload("res://scripts/attack_presentation.gd").new()
var presentation=preload("res://scripts/battle_presentation.gd").new()
var blood_faces=preload("res://scripts/blood_faces.gd").new()
var visuals
var selected_id=-1
var show_ranges=true
var time=0.0
var visual_elapsed=0.0
var visual_revision=-1
var visual_sim
var playback_speed=1
var staging=""
var debug_geometry=false
var debug_paths=false
var debug_vectors=false
var debug_ranges=false
var diagnostics=preload("res://scripts/debug_overlay.gd").new()
var warning_wave=[]
var warning_sources=[]
var warning_time=0.0
var arrivals={}
var known_cells={}
var arrival_sim_seed=-1
var arrival_round=-1
var font=ThemeDB.fallback_font
var drag_preview=Vector2.INF

func _process(delta):
	var visual_delta=delta
	if sim!=null:
		if visual_sim!=sim or visual_revision!=sim.presentation_revision or sim.elapsed<visual_elapsed:
			visual_elapsed=sim.elapsed
			known_cells.clear()
			arrivals.clear()
		visual_delta=maxf(0,sim.elapsed-visual_elapsed) if sim.phase=="battle" else delta
		visual_elapsed=sim.elapsed
		visual_sim=sim
		visual_revision=sim.presentation_revision
	if sim!=null: diagnostics.update(sim,delta)
	if sim!=null:
		microscope_effects.update(sim,delta)
		presentation.update(sim,delta)
		attacks.update(sim,delta)
		reactions.update(sim,delta)
		virus_behavior.update(sim,delta)
		support.update(sim,delta)
		attention.update(sim,delta,blood_faces)
		sources.update(sim,warning_wave if staging=="warning" else sim.wave,warning_sources if staging=="warning" else sim.infection_sources,staging,delta)
	warning_time+=delta
	if sim!=null:
		if arrival_sim_seed!=sim.seed_value or arrival_round!=sim.round_no:
			known_cells.clear()
			arrivals.clear()
			arrival_sim_seed=sim.seed_value
			arrival_round=sim.round_no
			for c in sim.cells: known_cells[c.id]=true
		for c in sim.cells:
			if not known_cells.has(c.id) and sim.phase=="shop": arrivals[c.id]=0.0
			known_cells[c.id]=true
		for id in arrivals.keys():
			arrivals[id]+=delta
			if arrivals[id]>0.65: arrivals.erase(id)
	if sim!=null: blood_faces.update(sim,visual_delta)
	time+=visual_delta
	queue_redraw()

func text_at(p, text, size=14, color=Color("#d8e9e5")):
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw():
	if sim==null: return
	microscope_effects.draw_under(self)
	for lane in sources.states:
		var source=sources.states[lane]
		if new_field:
			draw_circle(source.p,60+source.opening*6+sin(sources.clock*0.8+lane)*1.5,Color(0.38,0.34,0.45,0.35+source.opening*0.08))
			if not new_hud and (sim.phase=="shop" or staging=="warning"): draw_range_ring(source.p,66,Color("#be4a68"),true)
		else: sources.draw(self,lane)
		if staging=="warning" and source.active and not new_hud: draw_warning(source.p,lane)
	# Range underneath bodies and hands.
	var selected=sim.cell_by_id(selected_id)
	if not selected.is_empty() and selected.alive:
		var radius=sim.range_of(selected)
		if radius>0 and show_ranges and sim.phase=="shop":
			draw_circle(selected.p,radius,Color(0.08,0.36,0.46,0.11))
			draw_range_ring(selected.p,radius,Color("#245a70"))
		if selected.key=="orbiter" and show_ranges and sim.phase=="shop":
			draw_range_ring(Vector2.ZERO,maxf(100,selected.p.length()),Color("#794e96"),true)
	if sim.phase=="shop" and not selected.is_empty() and selected.key=="bodyguard":
		for link in sim.links:
			if link.owner!=selected.id: continue
			var other=sim.endpoint_by_id(link.b)
			if other.is_empty(): continue
			draw_line(selected.p,other.p,Color("#f4cf79"),2,true)
			text_at(other.p+Vector2(-20,-28),"Protected",12,Color("#245a70"))
	presentation.draw_bonds(self,"immune")
	draw_blood_cluster()
	for c in sim.cells:
		if c.alive: draw_cell(c)
	for p in sim.particles:
		if p.kind=="bullet":
			draw_circle(p.p,p.r+2,Color(0.8,0.95,1,0.15))
			draw_circle(p.p,p.r,Color("#bbe5ee"))
			draw_arc(p.p,p.r,0,TAU,14,Color("#e8faf9"),1,true)
		elif p.kind=="tag":
			draw_colored_polygon(PackedVector2Array([p.p+Vector2(0,-6),p.p+Vector2(5,4),p.p+Vector2(-5,4)]),Color("#ef9cbe"))
			draw_polyline(PackedVector2Array([p.p+Vector2(0,-6),p.p+Vector2(5,4),p.p+Vector2(-5,4),p.p+Vector2(0,-6)]),Color("#803f64"),1.2,true)
		else:
			draw_colored_polygon(PackedVector2Array([p.p+Vector2(0,-4),p.p+Vector2(4,0),p.p+Vector2(0,4),p.p+Vector2(-4,0)]),Color("#795791"))
	virus_behavior.draw_links(self)
	virus_health.clear()
	for v in sim.viruses:
		if v.alive: draw_virus(v)
	for label in virus_health:
		draw_set_transform(label[0],0,label[1])
		draw_string(font,Vector2(12,-9),label[2],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#e7efe1"))
	draw_set_transform(Vector2.ZERO)
	effect_strokes.begin()
	for e in sim.effects:
		var alpha=e.life/e.max
		var color=Color(e.color,alpha*flash_intensity)
		if e.has("end"):
			draw_line(e.p,e.end,color,3,true)
		else:
			effect_strokes.arc(self,e.p,e.r*(1.3-alpha*0.5),0,TAU,36,color,2)
			if e.text!="": text_at(e.p+Vector2(-12,-30-(1-alpha)*20),e.text,15,Color(e.color,alpha))
	if not selected.is_empty() and selected.alive:
		var p=selected.p
		draw_arc(p,27,0,TAU,48,Color("#f8e3a7"),2,true)
		if sim.phase=="shop":
			var tip=p+Vector2.RIGHT.rotated(selected.angle)*62
			draw_line(p+Vector2.RIGHT.rotated(selected.angle)*28,tip,Color("#f8e3a7"),2,true)
			draw_circle(tip,8,Color("#f4df9d"))
			var d=Vector2.RIGHT.rotated(selected.angle)
			draw_colored_polygon(PackedVector2Array([tip+d*5,tip-d*3+d.orthogonal()*4,tip-d*3-d.orthogonal()*4]),Color("#283d49"))
	microscope_effects.draw_over(self)
	presentation.draw_events(self)
	reactions.draw(self)
	virus_behavior.draw_effects(self)
	support.draw(self)
	if not new_hud: attention.draw(self)
	diagnostics.draw(self)
	if drag_preview!=Vector2.INF:
		draw_arc(drag_preview,24,0,TAU,32,Color("#f3e1ac"),2,true)

func face_part(index: int,p: Vector2,factor: float):
	draw_texture_rect_region(CELL_FACE_PARTS,Rect2(p-Vector2(16,16)*factor,Vector2(32,32)*factor),Rect2(index*256,0,256,256))
func face(p, factor, id, hurt, look=Vector2.ZERO,focused=false):
	var blink=fmod(time+id*0.71,4.8)<0.14
	var closed=blink or hurt or staging=="aftermath"
	face_part(1 if closed else 0,p if closed else p+look,factor)
	if focused:face_part(2,p,factor)
	var mouth=4 if staging=="launch" or focused else (5 if staging=="aftermath" and (sim.round_losses.core>0 or sim.round_losses.cells>0) else 3)
	face_part(mouth,p,factor)
	face_part(6,p,factor)

func draw_cell(c):
	var d=sim.catalog[c.key]
	var color=Color(d.color)
	var pulse=1+sin(time*2+c.id)*0.035
	if staging=="launch": pulse=0.97
	if arrivals.has(c.id): pulse*=lerpf(0.55,1.0,smoothstep(0,0.4,arrivals[c.id]))
	var pose=attacks.poses.get(c.id,{})
	var windup=pose.get("windup",0.0)
	var kick=pose.get("kick",0.0)
	var reaction=reactions.pose("cell",c.id)
	pulse*=(1-windup*0.12+kick*0.16)*reaction.squash
	var p=c.p-pose.get("direction",Vector2.ZERO)*(windup*1.5+kick*3)+reaction.offset
	attacks.draw_intent(self,c)
	var wall=d.behavior=="wall"
	if new_field:
		draw_set_transform(p,c.angle,Vector2(pulse,1/pulse))
		if wall:
			if not wall_skins.has(color):
				var skin=StyleBoxFlat.new()
				skin.bg_color=color
				skin.border_color=color.darkened(0.4)
				skin.set_border_width_all(2)
				skin.set_corner_radius_all(13)
				wall_skins[color]=skin
			draw_style_box(wall_skins[color],Rect2(-43,-13,86,26))
		else:
			draw_circle(Vector2.ZERO,23,color)
			draw_arc(Vector2.ZERO,23,0,TAU,48,color.darkened(0.45),2,true)
		draw_set_transform(Vector2.ZERO)
	else:
		var texture=visuals.body(c.key,d)
		var extent=Vector2(106,80) if wall else Vector2(58,58)
		draw_set_transform(p+Vector2(2,4),c.angle,Vector2(pulse,1/pulse))
		draw_texture_rect(texture,Rect2(-extent/2,extent),false,Color(0.06,0.15,0.2,0.2))
		if optical_intensity>0:
			draw_set_transform(p,c.angle)
			draw_texture_rect(texture,Rect2(-extent*0.54,extent*1.08),false,Color(0.78,0.94,1,0.14*optical_intensity))
		draw_set_transform(p,c.angle,Vector2(pulse,1/pulse))
		draw_texture_rect(texture,Rect2(-extent/2,extent),false,visuals.tint(c.key,d))
		draw_set_transform(Vector2.ZERO)
	if not new_field and not wall and optical_intensity>0:
		draw_arc(p,25,PI*1.05,PI*1.48,18,Color(0.88,0.98,1,0.5*optical_intensity),1.3,true)
	var look=pose.get("look",Vector2.ZERO)
	if sim.phase=="shop":
		var nearest={}
		var distance=120.0
		for other in sim.cells:
			if other.id!=c.id and other.alive and p.distance_to(other.p)<distance:
				nearest=other
				distance=p.distance_to(other.p)
		if not nearest.is_empty(): look=p.direction_to(nearest.p)*1.3
	face(p,0.95,c.id,c.flash>0 or reaction.hurt,look,windup>0.2 or kick>0.5)
	if arrivals.has(c.id):
		var arrival=arrivals[c.id]/0.65
		draw_arc(p,20+arrival*22,0,TAU,40,Color(0.8,1,1,1-arrival),1.5,true)
	support.draw_cell(self,c)
	if c.key=="bandage":
		draw_line(p+Vector2(-8,-12),p+Vector2(8,-12),Color("#fff7df"),5,true)
	if c.key=="bank":
		draw_circle(p+Vector2(0,12),4,Color("#ffe49b"))
	if c.charge>0:
		text_at(p+Vector2(-5,-27),"ϟ",18,Color("#ffe89a"))
	if c.rank>1:
		for i in range(c.rank):
			draw_circle(p+Vector2(-6+(i*6),-27),2.2,Color("#ffe6a1"))
	if c.rank==3:
		draw_arc(p,23,0,TAU,40,Color("#f5db91"),1.4,true)
	var fraction=clampf(c.hp/maxf(c.max_hp,c.hp),0,1)
	draw_texture_rect_region(CELL_FACE_PARTS,Rect2(p+Vector2(-14,22),Vector2(28,8)),Rect2(1808,96,224,64),Color("#29424b"))
	if fraction>0:draw_texture_rect_region(CELL_FACE_PARTS,Rect2(p+Vector2(-14,22),Vector2(28*fraction,8)),Rect2(1808,96,224,64),Color("#cae2b0"))
	text_at(p+Vector2(18,31),str(int(ceil(c.hp))),10,Color("#e7efe1"))

func capsule_style(color):
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.corner_radius_top_left=12
	s.corner_radius_top_right=12
	s.corner_radius_bottom_left=12
	s.corner_radius_bottom_right=12
	return s

func draw_virus(v):
	var reaction=reactions.pose("virus",v.id)
	reaction.squash*=virus_behavior.scale_of(v.id)
	var windup=attacks.jumper_pose(v)
	var recovery=attacks.jumper_recovery(v)
	var stretch=0.14 if v.jump else -recovery*0.1
	draw_set_transform(v.p+reaction.offset,0,Vector2((1+windup*0.2+stretch)*reaction.squash,(1-windup*0.18-stretch)/reaction.squash))
	if not new_field and v.hp>1:
		virus_health.append([v.p+reaction.offset,Vector2((1+windup*0.2+stretch)*reaction.squash,(1-windup*0.18-stretch)/reaction.squash),str(int(v.hp))])
	var rendered=v.duplicate()
	rendered.defer_health=true
	rendered.p=Vector2.ZERO
	rendered.hurt=reaction.hurt
	rendered.look=virus_behavior.looks.get(v.id,Vector2.ZERO)
	rendered.feeding=virus_behavior.feeding.has(v.id)
	if new_field:
		draw_texture_rect(SIMPLE_VIRUS_BODY,Rect2(-16,-16,32,32),false)
		draw_texture_rect(SIMPLE_VIRUS_EYES,Rect2(rendered.look-Vector2(16,16),Vector2(32,32)),false)
	else: preload("res://scripts/virus_visuals.gd").draw(self,rendered)
	draw_set_transform(Vector2.ZERO)
	if v.get("visual_avoiding",false) and v.get("freeze",0)<=0:
		var heading=v.get("visual_heading",Vector2.ZERO).angle()
		draw_arc(v.p,19,heading-0.4,heading+0.4,12,Color("#d6b2e5"),1.5,true)
	if windup>0:
		draw_arc(v.p,21,PI*0.1,PI*0.9,20,Color(0.58,0.27,0.66,windup),2,true)

func draw_range_ring(center,radius,color,dashed=false):
	# Keep the boundary readable at every camera zoom, including on bright art.
	var zoom=maxf(get_global_transform().get_scale().x,0.01)
	var segments=clampi(int(ceil(TAU*radius*zoom/5.0)),64,512)
	draw_arc(center,radius,0,TAU,segments,Color(1,1,1,0.85),5.0/zoom,true)
	if dashed:
		for i in range(48):
			var start=i*TAU/48.0
			draw_arc(center,radius,start,start+TAU/48.0*0.62,8,color,2.5/zoom,true)
	else:
		draw_arc(center,radius,0,TAU,segments,color,2.5/zoom,true)

func draw_warning(center,lane):
	# These are forecast markers only: no virus actors or collision bodies exist yet.
	for ring in range(3):
		var progress=fmod(warning_time*0.45+ring/3.0,1.0)
		draw_arc(center,38+progress*48,0,TAU,64,Color(0.76,0.92,1,(1-progress)*0.55),2,true)
	text_at(center+Vector2(-30,-66),"SOURCE %d" % (lane+1),12,Color("#365b70"))
	var entries=warning_wave.filter(func(e): return e.lane==lane)
	for i in range(entries.size()):
		var entry=entries[i]
		var marker=center+Vector2((i-(entries.size()-1)*0.5)*46,55)
		draw_circle(marker,20,Color(0.82,0.91,0.96,0.7))
		preload("res://scripts/virus_visuals.gd").draw(self,{"p":marker,"type":entry.type,"jump":false,"tag":0,"hp":1})
		text_at(marker+Vector2(-8,32),str(entry.count),13,Color("#365b70"))

func draw_blood_cluster():
	var occupied={}
	for link in sim.blood_links:
		var a=sim.blood[link.a]
		var b=sim.blood[link.b]
		if not a.alive or not b.alive: continue
		var direction=a.p.direction_to(b.p)
		var slot_a=posmod(roundi(direction.angle()/(TAU/6)),6)
		var slot_b=posmod(slot_a+3,6)
		var key_a=str(a.id)+":"+str(slot_a)
		var key_b=str(b.id)+":"+str(slot_b)
		if occupied.has(key_a) or occupied.has(key_b): continue
		occupied[key_a]=true
		occupied[key_b]=true
	# Keep each visual layer contiguous so the renderer can batch it. The hair
	# tips still mark radius 13; root sway and phase are unchanged.
	var hairs=PackedVector2Array()
	for b in sim.blood:
		if not b.alive:continue
		var p: Vector2=b.p
		draw_texture_rect_region(CORE_FACE_PARTS,Rect2(p+Vector2(1,2)-Vector2(16,16),Vector2(32,32)),Rect2(1280,256,256,256),Color(1,1,1,0.22))
		for i in range(30):
			var tangent: Vector2=hair_tangents[i]*sin(time*1.8+b.id+i)*0.22
			hairs.append(p+hair_roots[i]+tangent)
			hairs.append(p+hair_tips[i])
	if not hairs.is_empty():draw_multiline(hairs,Color("#b96b82"),0.75,true)
	for b in sim.blood:
		if not b.alive:continue
		var mask=0
		for slot in range(6):
			if occupied.has(str(b.id)+":"+str(slot)):mask|=1<<slot
		var texture=SIMPLE_CORE_BODIES if new_field else CLASSIC_CORE_BODIES
		draw_texture_rect_region(texture,Rect2(b.p-Vector2(16,16),Vector2(32,32)),Rect2(Vector2(mask%8,mask/8)*128,Vector2(128,128)))

	presentation.draw_bonds(self,"core")
	blood_faces.begin_draw()
	for b in sim.blood:
		if b.alive: blood_faces.draw(self,b,time)
	blood_faces.finish_draw(self)

func has_transient_effects():
	return not presentation.signals.is_empty() or not presentation.hits.is_empty() or not reactions.bursts.is_empty() or not virus_behavior.effects.is_empty() or not support.effects.is_empty() or not attention.active.is_empty()
