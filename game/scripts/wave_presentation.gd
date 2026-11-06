extends RefCounted
var observed_sim
var revision=-1
var cursor=0
var elapsed=0.0
var fronts=[]
var ripples=[]
func update(sim,delta):
 var fresh=observed_sim!=sim or revision!=sim.presentation_revision
 if fresh or sim.elapsed<elapsed:
  fronts.clear();ripples.clear()
  if fresh:cursor=sim.event_sequence
  elapsed=sim.elapsed
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 observed_sim=sim;revision=sim.presentation_revision;elapsed=sim.elapsed
 for ripple in ripples:ripple.age+=dt
 ripples= ripples.filter(func(r):return r.age<r.life)
 for e in sim.events_since(cursor):
  if e.event=="blast_started":
   var d=e.data
   ripples.append({"p":d.p,"reach":d.reach,"age":0.0,"life":d.duration+0.45,"duration":d.duration,"damage":d.damage})
 cursor=sim.event_sequence
 if ripples.size()>24:ripples=ripples.slice(ripples.size()-24)
 fronts.clear()
 for blast in sim.blasts:
  fronts.append({"p":blast.p,"radius":blast.radius,"damage":blast.damage})
func draw(canvas):
 # Solid boundary tracks the real front exactly. Trailing water is faint/dashed.
 for front in fronts:
  var tint=Color("#d46d91") if front.damage>0 else Color("#6ca7be")
  canvas.draw_arc(front.p,maxf(0.1,front.radius),0,TAU,40,Color(tint,0.65),1.5,true)
 for ripple in ripples:
  var progress=clampf(ripple.age/maxf(0.01,ripple.duration),0,1)
  var r=ripple.reach*progress*0.88
  var alpha=(1-ripple.age/ripple.life)*0.20
  for i in range(6):
   var a=i*TAU/6
   canvas.draw_arc(ripple.p,maxf(0.1,r),a,a+0.55,6,Color(0.83,0.95,1,alpha),1.0,true)
