extends RefCounted
var strokes=preload("res://scripts/stroke_cache.gd").new()
var observed_sim
var revision=-1
var elapsed=0.0
var phase=""
var cursor=0
var trails=[]
var previous={}
var bursts=[]
var merges=[]
var intensity=1.0
var deaths_seen={}
var friendly_trail_seconds=0.6
var virus_trail_seconds=120.0
var virus_trail_head_seconds=3.0
var virus_trail_tail_weight=0.45
var launch_clear_seconds=0.2
func update(sim,delta,water_delta=-1.0):
 var fresh=observed_sim!=sim or revision!=sim.presentation_revision
 var starting_battle=sim.phase=="battle" and phase!="battle"
 if fresh:
  var profile=sim.rules.get("water_trails",{})
  friendly_trail_seconds=maxf(0.05,float(profile.get("friendly_seconds",0.6)))
  virus_trail_seconds=maxf(0.05,float(profile.get("virus_seconds",120.0)))
  virus_trail_head_seconds=maxf(0.05,float(profile.get("virus_head_seconds",3.0)))
  virus_trail_tail_weight=clampf(float(profile.get("virus_tail_weight",0.45)),0.0,1.0)
  launch_clear_seconds=maxf(0.01,float(profile.get("launch_clear_seconds",0.2)))
 if fresh or (sim.elapsed<elapsed and not starting_battle):
  trails.clear()
 elif starting_battle:
  # Preserve the old field long enough to dissolve it, without drawing a line
  # from a restored preparation position to the previous battle's endpoint.
  for segment in trails: segment["clear_age"]=0.0
 if fresh or sim.elapsed<elapsed or starting_battle:
  previous.clear()
  bursts.clear()
  merges.clear()
  deaths_seen.clear()
  if fresh: cursor=sim.event_sequence
  elapsed=sim.elapsed
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 observed_sim=sim
 revision=sim.presentation_revision
 elapsed=sim.elapsed
 phase=sim.phase
 # Water remembers rendered motion, not accelerated simulation time. Freeze
 # during battle pause; death/merge effects below keep their existing clock.
 # The scene supplies its pause-aware render clock: an idle fixed-step frame
 # at 120/240 Hz is not a pause. Standalone callers can infer from sim time.
 var water_dt=water_delta if water_delta>=0 else (maxf(0,delta) if sim.phase!="battle" or dt>0 else 0.0)
 for segment in trails:
  segment.age+=water_dt
  if segment.has("clear_age"):segment.clear_age+=water_dt
 trails=trails.filter(func(s): return s.age<s.life and s.get("clear_age",0.0)<launch_clear_seconds)
 var alive={}
 if sim.phase=="battle":
  for bodies in [sim.viruses,sim.cells,sim.blood]:
   for body in bodies:
    if not body.alive or body.get("emerging",false): continue
    var id=sim.physics.id_of(body)
    alive[id]=true
    if previous.has(id):
     var distance=previous[id].distance_to(body.p)
     if distance>=5 and distance<100:
      var is_virus=body.has("type")
      trails.append({"a":previous[id],"b":body.p,"age":0.0,"virus":is_virus,"life":virus_trail_seconds if is_virus else friendly_trail_seconds})
      previous[id]=body.p
     elif distance>=100: previous[id]=body.p
    else: previous[id]=body.p
 for id in previous.keys():
  if not alive.has(id): previous.erase(id)
 if trails.size()>420: trails=trails.slice(trails.size()-420)
 for b in bursts: b.age+=dt
 for m in merges: m.age+=dt
 bursts=bursts.filter(func(b): return b.age<0.7)
 merges=merges.filter(func(m): return m.age<1.0)
 for e in sim.events_since(cursor):
  if e.event in ["virus_defeated","cell_rest","blood_lost"]:
   var identity=e.event+":"+str(e.data.get("id",e.seq))
   if deaths_seen.has(identity): continue
   deaths_seen[identity]=true
   var body=sim.cell_by_id(e.data.get("id",-1)) if e.event=="cell_rest" else {}
   bursts.append({"p":e.data.p,"kind":e.event,"age":0.0,"angle":body.get("angle",0.0),"wall":body.has("key") and sim.catalog[body.key].behavior=="wall"})
  elif e.event=="merge" and e.data.has("p"):
   merges.append({"p":e.data.p,"rank":e.data.rank,"age":0.0})
 cursor=sim.event_sequence
 if bursts.size()>32: bursts=bursts.slice(bursts.size()-32)
 if merges.size()>8: merges=merges.slice(merges.size()-8)
func trail_strength(segment):
 var remaining=maxf(0.0,1.0-segment.age/segment.life)
 var strength=remaining
 if segment.virus:
  # Original observations establish a short strong impression and a long weak
  # residue, not a universal lifetime. These are our provisional visual curves.
  var head=maxf(0.0,1.0-segment.age/minf(segment.life,virus_trail_head_seconds))
  var tail=remaining*remaining
  strength=(1.0-virus_trail_tail_weight)*head*head+virus_trail_tail_weight*tail
 if segment.has("clear_age"):
  strength*=maxf(0.0,1.0-segment.clear_age/launch_clear_seconds)
 return strength
func draw_under(canvas):
 strokes.begin()
 var density=1.0/maxf(1.0,trails.size()/150.0)
 var points=PackedVector2Array()
 var colors=PackedColorArray()
 for s in trails:
  var alpha=trail_strength(s)*0.26*density*intensity
  points.append(s.a);points.append(s.b)
  colors.append(Color(0.56,0.35,0.70,alpha) if s.virus else Color(0.74,0.94,0.97,alpha))
 if not points.is_empty():canvas.draw_multiline_colors(points,colors,4,true)
 for b in bursts:
  var t=b.age/0.7
  draw_departure(canvas,b,t)
  var preset=death_particles(b.kind)
  var color=Color(preset.color,(1-t)*preset.alpha*intensity)
  for i in range(preset.count):
   var a=i*TAU/preset.count
   var p=b.p+Vector2.from_angle(a)*(12+t*preset.spread)
   if b.kind=="virus_defeated":
    canvas.draw_circle(p,(3-t*2)*intensity,color)
   elif b.kind=="cell_rest":
    p.y-=t*12
    var d=Vector2.from_angle(a)*(4*(1-t))
    canvas.draw_line(p-d,p+d,color,1.5,true)
   else:
    strokes.arc(canvas,p,9*(1-t)+1,a,1.3,8,color,2)
func death_particles(kind):
 if kind=="blood_lost": return {"count":8,"spread":85.0,"color":Color("#e64d75"),"alpha":0.45}
 if kind=="cell_rest": return {"count":6,"spread":32.0,"color":Color("#62a49c"),"alpha":0.6}
 return {"count":5,"spread":25.0,"color":Color("#a375b8"),"alpha":0.6}
func draw_departure(canvas,b,t):
 # Non-gameplay echoes disappear within the existing aftermath interval.
 var alpha=(1-t)*intensity
 if b.kind=="blood_lost":
  # Six released hand positions and a contracting shell make Core loss distinct.
  var r=13*(1-t*0.6)
  strokes.arc(canvas,b.p,r,0,TAU,24,Color(0.77,0.24,0.38,alpha),2)
  for i in range(6):
   var d=Vector2.from_angle(i*TAU/6)
   canvas.draw_circle(b.p+d*(16+t*8),2*(1-t),Color(0.9,0.43,0.52,alpha))
 elif b.kind=="cell_rest":
  # Immune cells leave an upward-opening soft shell, preserving a Wall outline.
  var p=b.p+Vector2(0,-t*10)
  if b.wall:
   var d=Vector2.RIGHT.rotated(b.angle)
   for side in [-1,1]:
    var n=d.orthogonal()*side*(12+t*5)
    canvas.draw_line(p-d*34+n,p+d*34+n,Color(0.38,0.63,0.61,alpha),2,true)
  else:
   strokes.arc(canvas,p,22*(1-t*0.25),PI*0.1,PI*0.8,20,Color(0.38,0.63,0.61,alpha),2)
   strokes.arc(canvas,p,22*(1-t*0.25),PI*1.1,PI*0.8,20,Color(0.38,0.63,0.61,alpha),2)
 else:
  # Virus membrane breaks outward into short segments rather than a Core echo.
  for i in range(5):
   var a=i*TAU/5
   # The five pieces share topology and radius; rotate the cached mesh instead
   # of rebuilding five native antialiased polylines for every fading membrane.
   strokes.arc(canvas,b.p,12+t*18,a,0.6,5,Color(0.58,0.35,0.68,alpha),1.5)
func draw_over(canvas):
 for m in merges:
  var color=Color("#e6ad39") if m.rank==3 else Color("#f3f9ff")
  color.a=1-m.age
  canvas.draw_arc(m.p,28+m.age*24,0,TAU,40,color,2,true)
  canvas.draw_string(ThemeDB.fallback_font,m.p+Vector2(-25,-30-m.age*15),str(m.rank)+"/3",HORIZONTAL_ALIGNMENT_LEFT,-1,28,color)
