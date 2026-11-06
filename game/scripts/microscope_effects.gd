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
func update(sim,delta):
 var fresh=observed_sim!=sim or revision!=sim.presentation_revision
 if fresh or sim.elapsed<elapsed or (sim.phase=="battle" and phase!="battle"):
  trails.clear()
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
 var density=clampf(trails.size()/280.0,1.0,2.5)
 for segment in trails: segment.age+=dt*density
 trails=trails.filter(func(s): return s.age<1.8)
 var alive={}
 if sim.phase=="battle":
  for v in sim.viruses:
   if not v.alive: continue
   alive[v.id]=true
   if previous.has(v.id):
    var distance=previous[v.id].distance_to(v.p)
    if distance>=5 and distance<100:
     trails.append({"a":previous[v.id],"b":v.p,"age":0.0})
     previous[v.id]=v.p
    elif distance>=100: previous[v.id]=v.p
   else: previous[v.id]=v.p
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
func draw_under(canvas):
 strokes.begin()
 var density=1.0/maxf(1.0,trails.size()/150.0)
 var points=PackedVector2Array()
 var colors=PackedColorArray()
 for s in trails:
  var alpha=(1-s.age/1.8)*0.26*density*intensity
  points.append(s.a);points.append(s.b)
  colors.append(Color(0.56,0.35,0.70,alpha))
 if not points.is_empty():canvas.draw_multiline_colors(points,colors,4,true)
 for b in bursts:
  var t=b.age/0.7
  var core=b.kind=="blood_lost"
  draw_departure(canvas,b,t)
  var color=Color(0.9,0.3,0.46,(1-t)*0.45*intensity) if core else Color(0.64,0.46,0.72,(1-t)*0.6*intensity)
  for i in range(8 if core else 5):
   var a=i*TAU/(8 if core else 5)
   var p=b.p+Vector2.from_angle(a)*(12+t*(85 if core else 25))
   strokes.arc(canvas,p,(9 if core else 4)*(1-t)+1,a,1.3,8,color,2)
func draw_departure(canvas,b,t):
 # Non-gameplay echoes disappear within the existing aftermath interval.
 var alpha=(1-t)*intensity
 if b.kind=="blood_lost":
  # Six released hand positions and a contracting shell make Core loss distinct.
  var r=13*(1-t*0.6)
  canvas.draw_arc(b.p,r,0,TAU,24,Color(0.77,0.24,0.38,alpha),2,true)
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
   canvas.draw_arc(p,22*(1-t*0.25),PI*0.1,PI*0.9,20,Color(0.38,0.63,0.61,alpha),2,true)
   canvas.draw_arc(p,22*(1-t*0.25),PI*1.1,PI*1.9,20,Color(0.38,0.63,0.61,alpha),2,true)
 else:
  # Virus membrane breaks outward into short segments rather than a Core echo.
  for i in range(5):
   var a=i*TAU/5
   canvas.draw_arc(b.p,12+t*18,a,a+0.6,5,Color(0.58,0.35,0.68,alpha),1.5,true)
func draw_over(canvas):
 for m in merges:
  var color=Color("#e6ad39") if m.rank==3 else Color("#f3f9ff")
  color.a=1-m.age
  canvas.draw_arc(m.p,28+m.age*24,0,TAU,40,color,2,true)
  canvas.draw_string(ThemeDB.fallback_font,m.p+Vector2(-25,-30-m.age*15),str(m.rank)+"/3",HORIZONTAL_ALIGNMENT_LEFT,-1,28,color)
