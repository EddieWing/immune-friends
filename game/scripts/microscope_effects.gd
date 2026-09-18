extends RefCounted
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
func update(sim,delta):
 var fresh=observed_sim!=sim or revision!=sim.presentation_revision
 if fresh or sim.elapsed<elapsed or (sim.phase=="battle" and phase!="battle"):
  trails.clear()
  previous.clear()
  bursts.clear()
  merges.clear()
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
   bursts.append({"p":e.data.p,"kind":e.event,"age":0.0})
  elif e.event=="merge" and e.data.has("p"):
   merges.append({"p":e.data.p,"rank":e.data.rank,"age":0.0})
 cursor=sim.event_sequence
 if bursts.size()>32: bursts=bursts.slice(bursts.size()-32)
 if merges.size()>8: merges=merges.slice(merges.size()-8)
func draw_under(canvas):
 var density=1.0/maxf(1.0,trails.size()/150.0)
 for s in trails:
  var alpha=(1-s.age/1.8)*0.26*density*intensity
  canvas.draw_line(s.a,s.b,Color(0.56,0.35,0.70,alpha),4,true)
 for b in bursts:
  var t=b.age/0.7
  var core=b.kind=="blood_lost"
  var color=Color(0.9,0.3,0.46,(1-t)*0.45*intensity) if core else Color(0.64,0.46,0.72,(1-t)*0.6*intensity)
  for i in range(8 if core else 5):
   var a=i*TAU/(8 if core else 5)
   var p=b.p+Vector2.from_angle(a)*(12+t*(85 if core else 25))
   canvas.draw_arc(p,(9 if core else 4)*(1-t)+1,a,a+1.3,8,color,2,true)
func draw_over(canvas):
 for m in merges:
  var color=Color("#e6ad39") if m.rank==3 else Color("#f3f9ff")
  color.a=1-m.age
  canvas.draw_arc(m.p,28+m.age*24,0,TAU,40,color,2,true)
  canvas.draw_string(ThemeDB.fallback_font,m.p+Vector2(-25,-30-m.age*15),str(m.rank)+"/3",HORIZONTAL_ALIGNMENT_LEFT,-1,28,color)
