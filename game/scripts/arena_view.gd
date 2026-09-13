extends Node2D
var sim
var visuals
var selected_id=-1
var show_ranges=true
var time=0.0
var playback_speed=1
var font=ThemeDB.fallback_font
var drag_preview=Vector2.INF

func _process(delta):
	time+=delta*(playback_speed if sim!=null and sim.phase=="battle" else 1)
	queue_redraw()

func text_at(p, text, size=14, color=Color("#d8e9e5")):
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw():
	var directions=[Vector2(620,0),Vector2(-620,0),Vector2(0,-370)]
	if sim==null: return
	var drawn_lanes=[]
	for entry in sim.wave:
		if entry.lane in drawn_lanes: continue
		drawn_lanes.append(entry.lane)
		var start=directions[entry.lane]
		var end=Vector2.ZERO
		for n in range(14):
			var a=start.lerp(end,n/15.0)
			var b=start.lerp(end,(n+0.4)/15.0)
			draw_line(a,b,Color(0.76,0.65,0.84,0.2),2,true)
		draw_ink_source(start,entry.lane)
	# Range underneath bodies and hands.
	var selected=sim.cell_by_id(selected_id)
	if not selected.is_empty() and selected.alive:
		var radius=sim.range_of(selected)
		if radius>0 and show_ranges:
			draw_circle(selected.p,radius,Color(0.08,0.36,0.46,0.11))
			draw_range_ring(selected.p,radius,Color("#245a70"))
		if selected.key=="orbiter" and show_ranges:
			draw_range_ring(Vector2.ZERO,maxf(100,selected.p.length()),Color("#794e96"),true)
	for l in sim.links:
		var a=sim.cell_by_id(l.a)
		var b=sim.cell_by_id(l.b)
		if not a.alive or not b.alive: continue
		var dir=a.p.direction_to(b.p)
		var p=a.p+dir*14
		var q=b.p-dir*14
		var mid=(p+q)*0.5
		var curve=dir.orthogonal()*sin(time*2+l.a)*3
		draw_line(p,mid+curve,Color("#30454f"),10,true)
		draw_line(mid+curve,q,Color("#30454f"),10,true)
		draw_line(p,mid+curve,Color(sim.catalog[a.key].color).lightened(0.12),6,true)
		draw_line(mid+curve,q,Color(sim.catalog[b.key].color).lightened(0.12),6,true)
		draw_circle(mid+curve,6,Color("#f5dfcb"))
		draw_arc(mid+curve,6,-PI/2,PI/2,12,Color("#998a87"),1,true)
	for b in sim.blood:
		if not b.alive: continue
		draw_circle(b.p+Vector2(2,4),14,Color(0.05,0.13,0.17,0.3))
		draw_circle(b.p,13,Color("#df8998"))
		draw_circle(b.p+Vector2(-2,-2),10,Color("#eca2ac"))
		draw_arc(b.p,7,0,TAU,24,Color("#c97688"),2,true)
		face(b.p,0.62,b.id,false)
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
	if drag_preview!=Vector2.INF:
		draw_arc(drag_preview,24,0,TAU,32,Color("#f3e1ac"),2,true)

func face(p, factor, id, hurt):
	var blink=fmod(time+id*0.71,4.8)<0.14
	for x in [-6,6]:
		var eye=p+Vector2(x,-2)*factor
		if blink or hurt:
			draw_line(eye+Vector2(-2,0)*factor,eye+Vector2(2,0)*factor,Color("#33434c"),1.8,true)
		else:
			draw_circle(eye,2.0*factor,Color("#33434c"))
			draw_circle(eye+Vector2(-0.5,-0.5)*factor,0.55*factor,Color("#fff7e6"))
	draw_arc(p+Vector2(0,1)*factor,3.5*factor,0.15,PI-0.15,12,Color("#6c5260"),1.4,true)
	for x in [-11,11]:
		draw_circle(p+Vector2(x,3)*factor,2.6*factor,Color(0.95,0.51,0.59,0.38))

func draw_cell(c):
	var d=sim.catalog[c.key]
	var color=Color(d.color)
	var pulse=1+sin(time*2+c.id)*0.035
	var p=c.p
	var wall=d.behavior=="wall"
	var texture=visuals.body(c.key,d)
	var extent=Vector2(106,80) if wall else Vector2(58,58)
	draw_set_transform(p+Vector2(2,4),c.angle,Vector2(pulse,1/pulse))
	draw_texture_rect(texture,Rect2(-extent/2,extent),false,Color(0.06,0.15,0.2,0.2))
	draw_set_transform(p,c.angle,Vector2(pulse,1/pulse))
	draw_texture_rect(texture,Rect2(-extent/2,extent),false,visuals.tint(c.key,d))
	draw_set_transform(Vector2.ZERO)
	face(p,0.95,c.id,c.flash>0)
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
	preload("res://scripts/virus_visuals.gd").draw(self,v,visuals.style)

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

func draw_ink_source(center,seed):
	if visuals.style==1:
		var extent=Vector2.ONE*(150+sin(time*0.3+seed)*7)
		draw_texture_rect(preload("res://scripts/virus_visuals.gd").texture("source"),Rect2(center-extent/2,extent),false,Color(1,1,1,0.8))
		return
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
