extends Node2D
var sim
var presentation=preload("res://scripts/battle_presentation.gd").new()
var blood_faces=preload("res://scripts/blood_faces.gd").new()
var visuals
var selected_id=-1
var show_ranges=true
var time=0.0
var playback_speed=1
var staging=""
var debug_geometry=false
var debug_paths=false
var debug_vectors=false
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
	if sim!=null: diagnostics.update(sim,delta)
	if sim!=null: presentation.update(sim,delta)
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
	if sim!=null: blood_faces.update(sim,delta)
	time+=delta*(playback_speed if sim!=null and sim.phase=="battle" else 1)
	queue_redraw()

func text_at(p, text, size=14, color=Color("#d8e9e5")):
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw():
	if sim==null: return
	var drawn_lanes=[]
	var shown_wave=warning_wave if staging=="warning" else sim.wave
	var shown_sources=warning_sources if staging=="warning" else sim.infection_sources
	for entry in shown_wave:
		if entry.lane in drawn_lanes: continue
		drawn_lanes.append(entry.lane)
		var start=shown_sources[entry.lane]
		var end=sim.source_center
		for n in range(14):
			var a=start.lerp(end,n/15.0)
			var b=start.lerp(end,(n+0.4)/15.0)
			draw_line(a,b,Color(0.76,0.65,0.84,0.2),2,true)
		draw_ink_source(start,entry.lane)
		if staging=="warning": draw_warning(start,entry.lane)
	# Range underneath bodies and hands.
	var selected=sim.cell_by_id(selected_id)
	if not selected.is_empty() and selected.alive:
		var radius=sim.range_of(selected)
		if radius>0 and show_ranges:
			draw_circle(selected.p,radius,Color(0.08,0.36,0.46,0.11))
			draw_range_ring(selected.p,radius,Color("#245a70"))
		if selected.key=="orbiter" and show_ranges:
			draw_range_ring(Vector2.ZERO,maxf(100,selected.p.length()),Color("#794e96"),true)
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
			draw_colored_polygon(PackedVector2Array([p.p+Vector2(0,-6),p.p+Vector2(5,4),p.p+Vector2(-5,4)]),Color("#efc3d8"))
		else:
			draw_circle(p.p,3.5,Color("#ccb6e2"))
	for v in sim.viruses:
		if v.alive: draw_virus(v)
	for e in sim.effects:
		var alpha=e.life/e.max
		var color=Color(e.color,alpha)
		if e.has("end"):
			draw_line(e.p,e.end,color,3,true)
		else:
			draw_arc(e.p,e.r*(1.3-alpha*0.5),0,TAU,36,color,2,true)
			if e.text!="": text_at(e.p+Vector2(-12,-30-(1-alpha)*20),e.text,15,color)
	if not selected.is_empty() and selected.alive:
		var p=selected.p
		draw_arc(p,27,0,TAU,48,Color("#f8e3a7"),2,true)
		if sim.phase=="shop":
			var tip=p+Vector2.RIGHT.rotated(selected.angle)*62
			draw_line(p+Vector2.RIGHT.rotated(selected.angle)*28,tip,Color("#f8e3a7"),2,true)
			draw_circle(tip,8,Color("#f4df9d"))
			var d=Vector2.RIGHT.rotated(selected.angle)
			draw_colored_polygon(PackedVector2Array([tip+d*5,tip-d*3+d.orthogonal()*4,tip-d*3-d.orthogonal()*4]),Color("#283d49"))
	presentation.draw_events(self)
	diagnostics.draw(self)
	if drag_preview!=Vector2.INF:
		draw_arc(drag_preview,24,0,TAU,32,Color("#f3e1ac"),2,true)

func face(p, factor, id, hurt, look=Vector2.ZERO):
	var blink=fmod(time+id*0.71,4.8)<0.14
	for x in [-6,6]:
		var eye=p+Vector2(x,-2)*factor
		if blink or hurt or staging=="aftermath":
			draw_line(eye+Vector2(-2,0)*factor,eye+Vector2(2,0)*factor,Color("#33434c"),1.8,true)
		else:
			draw_circle(eye+look,2.0*factor,Color("#33434c"))
			draw_circle(eye+look+Vector2(-0.5,-0.5)*factor,0.55*factor,Color("#fff7e6"))
	if staging=="launch":
		draw_line(p+Vector2(-3,4)*factor,p+Vector2(3,4)*factor,Color("#6c5260"),1.4,true)
	elif staging=="aftermath" and (sim.round_losses.core>0 or sim.round_losses.cells>0):
		draw_line(p+Vector2(-3,5)*factor,p+Vector2(3,5)*factor,Color("#6c5260"),1.2,true)
	else: draw_arc(p+Vector2(0,1)*factor,3.5*factor,0.15,PI-0.15,12,Color("#6c5260"),1.4,true)
	for x in [-11,11]:
		draw_circle(p+Vector2(x,3)*factor,2.6*factor,Color(0.95,0.51,0.59,0.38))

func draw_cell(c):
	var d=sim.catalog[c.key]
	var color=Color(d.color)
	var pulse=1+sin(time*2+c.id)*0.035
	if staging=="launch": pulse=0.97
	if arrivals.has(c.id): pulse*=lerpf(0.55,1.0,smoothstep(0,0.4,arrivals[c.id]))
	var p=c.p
	var wall=d.behavior=="wall"
	var texture=visuals.body(c.key,d)
	var extent=Vector2(106,80) if wall else Vector2(58,58)
	draw_set_transform(p+Vector2(2,4),c.angle,Vector2(pulse,1/pulse))
	draw_texture_rect(texture,Rect2(-extent/2,extent),false,Color(0.06,0.15,0.2,0.2))
	draw_set_transform(p,c.angle,Vector2(pulse,1/pulse))
	draw_texture_rect(texture,Rect2(-extent/2,extent),false,visuals.tint(c.key,d))
	draw_set_transform(Vector2.ZERO)
	var look=Vector2.ZERO
	if sim.phase=="shop":
		var nearest={}
		var distance=120.0
		for other in sim.cells:
			if other.id!=c.id and other.alive and p.distance_to(other.p)<distance:
				nearest=other
				distance=p.distance_to(other.p)
		if not nearest.is_empty(): look=p.direction_to(nearest.p)*1.3
	face(p,0.95,c.id,c.flash>0,look)
	if arrivals.has(c.id):
		var arrival=arrivals[c.id]/0.65
		draw_arc(p,20+arrival*22,0,TAU,40,Color(0.8,1,1,1-arrival),1.5,true)
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
	draw_line(p+Vector2(-14,26),p+Vector2(14,26),Color("#29424b"),3,true)
	draw_line(p+Vector2(-14,26),p+Vector2(-14+28*fraction,26),Color("#cae2b0"),3,true)
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
	preload("res://scripts/virus_visuals.gd").draw(self,v)

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

func draw_ink_source(center,seed):
	for layer in range(7):
		var points=PackedVector2Array()
		var radius=72-layer*7
		for i in range(96):
			var angle=i*TAU/96.0
			var wobble=sin(angle*5+time*0.22+seed)*0.15+sin(angle*9-time*0.17)*0.08
			points.append(center+Vector2.from_angle(angle)*(radius*(1+wobble)))
		draw_colored_polygon(points,Color(0.22,0.12,0.32,0.045+layer*0.012))
	for i in range(11):
		var angle=i*TAU/11+seed
		var trail=PackedVector2Array()
		for j in range(18):
			var t=j/17.0
			trail.append(center+Vector2.from_angle(angle+sin(t*4+time*0.24+i)*0.23)*(25+t*55))
		draw_polyline(trail,Color(0.29,0.16,0.38,0.08),3,true)
	draw_circle(center,17,Color(0.18,0.09,0.25,0.38))

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
	for b in sim.blood:
		if not b.alive: continue
		draw_circle(b.p+Vector2(1,2),12,Color(0.05,0.13,0.17,0.22))
		# The hair tips lie on the actual radius-13 collision boundary.
		for i in range(30):
			var angle=i*TAU/30.0
			var normal=Vector2.from_angle(angle)
			var tangent=normal.orthogonal()*sin(time*1.8+b.id+i)*0.22
			draw_line(b.p+normal*10.7+tangent,b.p+normal*13.0,Color("#b96b82"),0.75,true)
		draw_circle(b.p,10.8,Color("#df8998"))
		draw_circle(b.p+Vector2(-1,-1),9,Color("#eca2ac"))
		draw_arc(b.p,7,0,TAU,24,Color("#c97688"),1.5,true)
		for slot in range(6):
			if occupied.has(str(b.id)+":"+str(slot)): continue
			var center=b.p+Vector2.from_angle(slot*TAU/6)*10.8
			draw_circle(center,2.2,Color("#b96b82"))
			draw_circle(center,1.5,Color("#f3b0b8"))
	presentation.draw_bonds(self,"core")
	for b in sim.blood:
		if b.alive: blood_faces.draw(self,b,time)
