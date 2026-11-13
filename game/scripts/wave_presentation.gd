extends RefCounted
var observed_sim
var revision=-1
var cursor=0
var elapsed=0.0
var fronts=[]
var ripples=[]
var heals=[]
func update(sim,delta):
 var fresh=observed_sim!=sim or revision!=sim.presentation_revision
 if fresh or sim.elapsed<elapsed:
  fronts.clear();ripples.clear();heals.clear()
  if fresh:cursor=sim.event_sequence
  elapsed=sim.elapsed
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 observed_sim=sim;revision=sim.presentation_revision;elapsed=sim.elapsed
 for ripple in ripples:ripple.age+=dt
 ripples= ripples.filter(func(r):return r.age<r.life)
 for h in heals:h.age+=dt
 heals=heals.filter(func(h):return h.age<0.65)
 var healed_sources={}
 for e in sim.events_since(cursor):
  if e.event=="blast_started":
   var d=e.data
   ripples.append({"p":d.p,"reach":d.reach,"age":0.0,"life":d.duration+0.45,"duration":d.duration,"damage":d.damage})
  elif e.event=="heal" and float(e.data.get("amount",0))>0:
   var source_id=e.data.get("source_id",-1)
   var source=sim.cell_by_id(source_id)
   if not source.is_empty() and not healed_sources.has(source_id):
    healed_sources[source_id]=true
    heals.append({"p":e.data["from"],"reach":sim.range_of(source),"age":0.0})
 cursor=sim.event_sequence
 if ripples.size()>24:ripples=ripples.slice(ripples.size()-24)
 if heals.size()>12:heals=heals.slice(heals.size()-12)
 fronts.clear()
 for blast in (sim.blasts if sim.phase=="battle" else []):
  fronts.append({"p":blast.p,"radius":blast.radius,"damage":blast.damage})
func has_transients():
 return not ripples.is_empty() or not heals.is_empty()
func draw(canvas):
 # Solid boundary tracks the real front exactly. Trailing water is faint/dashed.
 for front in fronts:
  var tint=Color("#d46d91") if front.damage>0 else Color("#6ca7be")
  canvas.draw_arc(front.p,maxf(0.1,front.radius),0,TAU,40,Color(tint,0.65),1.5,true)
  if front.damage<=0:
   for i in range(8):
    var d=Vector2.from_angle(i*TAU/8)
    var p=front.p+d*front.radius
    canvas.draw_polyline(PackedVector2Array([p-d*4+d.orthogonal()*3,p,p-d*4-d.orthogonal()*3]),Color(0.47,0.72,0.85,0.7),1.3,true)
 for h in heals:
  var t=h.age/0.65
  # Actual recipients flash immediately; this airy cross-wave is only a cast echo.
  var radius=h.reach*(0.3+0.7*t)
  for i in range(6):
   var p=h.p+Vector2.from_angle(i*TAU/6)*radius
   var color=Color(0.38,0.73,0.55,(1-t)*0.65)
   canvas.draw_line(p-Vector2(3,0),p+Vector2(3,0),color,1.5,true)
   canvas.draw_line(p-Vector2(0,3),p+Vector2(0,3),color,1.5,true)
 for ripple in ripples:
  var progress=clampf(ripple.age/maxf(0.01,ripple.duration),0,1)
  var r=ripple.reach*progress*0.88
  var alpha=(1-ripple.age/ripple.life)*0.20
  for i in range(6):
   var a=i*TAU/6
   canvas.draw_arc(ripple.p,maxf(0.1,r),a,a+0.55,6,Color(0.83,0.95,1,alpha),1.0,true)
