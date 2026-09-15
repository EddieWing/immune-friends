extends RefCounted
var revision_seen=-1
var observed_sim
var round_seen=-1
var phase_seen=""
var elapsed=0.0
var cursor=0
var reactions={}
var bursts=[]
func update(sim,delta):
 var fresh=observed_sim!=sim or revision_seen!=sim.presentation_revision
 revision_seen=sim.presentation_revision
 if fresh or round_seen!=sim.round_no or cursor>sim.event_sequence or sim.elapsed<elapsed or (sim.phase=="battle" and phase_seen!="battle"):
  reactions.clear()
  bursts.clear()
  cursor=sim.event_sequence if fresh else cursor
  elapsed=sim.elapsed
 observed_sim=sim
 round_seen=sim.round_no
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 elapsed=sim.elapsed
 phase_seen=sim.phase
 for key in reactions.keys():
  reactions[key].age+=dt
  if reactions[key].age>=0.38: reactions.erase(key)
 for burst in bursts: burst.age+=dt
 bursts=bursts.filter(func(b): return b.age<0.5)
 for e in sim.events_since(cursor):
  var d=e.data
  if e.event in ["damage","virus_hit","pushed"]:
   var kind=d.get("kind","cell" if e.event=="damage" else "virus")
   var key=kind+":"+str(d.id)
   reactions[key]={"age":0.0,"push":e.event=="pushed","direction":d.get("from",d.p).direction_to(d.p)}
  if e.event in ["virus_hit","pushed","tagged","thawed","tag_ended"]:
   bursts.append({"p":d.p,"age":0.0,"kind":e.event,"direction":d.get("from",d.p).direction_to(d.p)})
 cursor=sim.event_sequence
 if bursts.size()>48: bursts=bursts.slice(bursts.size()-48)
func pose(kind,id):
 var r=reactions.get(kind+":"+str(id),{})
 if r.is_empty(): return {"squash":1.0,"offset":Vector2.ZERO,"hurt":false}
 var weight=1-smoothstep(0,0.38,r.age)
 return {"squash":1+weight*(0.12 if r.push else -0.16),"offset":r.direction*weight*2,"hurt":not r.push and weight>0.25}
func draw(canvas):
 for b in bursts.slice(maxi(0,bursts.size()-16)):
  var t=b.age/0.5
  var color=Color(0.76,0.9,1,1-t) if b.kind in ["thawed","tagged"] else Color(0.94,0.64,0.75,1-t)
  if b.kind=="pushed":
   var d=b.direction
   var p=b.p-d*(23+t*8)
   canvas.draw_polyline(PackedVector2Array([p-d*6+d.orthogonal()*5,p,p-d*6-d.orthogonal()*5]),Color(0.94,0.76,0.43,1-t),2,true)
  elif b.kind in ["thawed","tag_ended"]:
   for i in range(5):
    var d=Vector2.from_angle(i*TAU/5)
    canvas.draw_line(b.p+d*(17+t*12),b.p+d*(20+t*15),color,1.5,true)
  else:
   for i in range(4):
    var d=Vector2.from_angle(i*PI/2+PI/4)
    canvas.draw_line(b.p+d*(13+t*10),b.p+d*(18+t*10),color,2,true)
