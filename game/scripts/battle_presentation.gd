extends RefCounted
var revision_seen=-1
var observed_sim
var round_seen=-1
var cursor=0
var elapsed=0.0
var bonds={}
var signals=[]
var hits=[]
func update(sim,delta):
 var fresh=observed_sim!=sim or revision_seen!=sim.presentation_revision
 revision_seen=sim.presentation_revision
 if fresh or round_seen!=sim.round_no or cursor>sim.event_sequence:
  observed_sim=sim
  round_seen=sim.round_no
  cursor=sim.event_sequence if fresh else cursor
  bonds.clear()
  signals.clear()
  hits.clear()
  elapsed=sim.elapsed
 delta=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 elapsed=sim.elapsed
 var active={}
 for link in sim.links:
  var a=sim.endpoint_by_id(link.a)
  var b=sim.endpoint_by_id(link.b)
  if a.is_empty() or b.is_empty() or not a.alive or not b.alive: continue
  observe_link(active,"immune",link.a,link.b,a.p,b.p,Color(sim.catalog[a.key].color) if a.has("key") else Color("#f2acb8"),Color(sim.catalog[b.key].color) if b.has("key") else Color("#f2acb8"),a,b)
 for link in sim.blood_links:
  var a=sim.blood[link.a]
  var b=sim.blood[link.b]
  if not a.alive or not b.alive: continue
  observe_link(active,"core",a.id,b.id,a.p,b.p,Color("#f2acb8"),Color("#f2acb8"),a,b)
 for key in bonds.keys():
  var bond=bonds[key]
  bond.connected=active.has(key)
  if bond.connected: bond.progress=minf(1,bond.progress+delta/0.25)
  else:
   bond.progress=maxf(0,bond.progress-delta/0.28)
   if bond.a.get("alive",false): bond.p=bond.a.p
   if bond.b.get("alive",false): bond.q=bond.b.p
   if bond.progress==0: bonds.erase(key)
 for e in sim.events_since(cursor):
  if e.event=="damage" and e.data.has("p"):
   var d=e.data
   hits.append({"p":d.p,"from":d.get("from",d.p),"kind":d.get("source_kind","unknown"),"age":0.0})
  elif e.event=="transfer" or e.event=="discharge":
   if e.data.get("path",[]).size()>1: signals.append({"path":e.data.path.duplicate(),"age":0.0,"kind":e.event})
  elif e.event=="blood_lost": hits.append({"p":e.data.p,"from":e.data.p,"kind":"core","age":0.0})
 cursor=sim.event_sequence
 for hit in hits: hit.age+=delta
 for pulse in signals: pulse.age+=delta
 hits=hits.filter(func(h): return h.age<0.65)
 signals=signals.filter(func(p): return p.age<0.85)
 if hits.size()>128: hits=hits.slice(hits.size()-128)
 if signals.size()>64: signals=signals.slice(signals.size()-64)
func observe_link(active,kind,id_a,id_b,p,q,ca,cb,a,b):
 var key=kind+":"+str(mini(id_a,id_b))+":"+str(maxi(id_a,id_b))
 active[key]=true
 if not bonds.has(key): bonds[key]={"progress":0.0,"connected":true,"kind":kind}
 var bond=bonds[key]
 bond.p=p
 bond.q=q
 bond.ca=ca
 bond.cb=cb
 bond.a=a
 bond.b=b
func draw_bonds(canvas,kind):
 for bond in bonds.values():
  if bond.kind!=kind: continue
  var core=kind=="core"
  var direction=bond.p.direction_to(bond.q)
  var start=bond.p+direction*(9.5 if core else 14.0)
  var end=bond.q-direction*(9.5 if core else 14.0)
  if core:
   start=bond.p+Vector2.from_angle(round(direction.angle()/(TAU/6))*(TAU/6))*9.5
   end=bond.q+Vector2.from_angle(round((-direction).angle()/(TAU/6))*(TAU/6))*9.5
  var middle=(start+end)*0.5
  var progress=smoothstep(0,1,bond.progress)
  var left=start.lerp(middle,progress)
  var right=end.lerp(middle,progress)
  var width=2.6 if core else 6.0
  canvas.draw_line(start,left,Color("#594352"),width+1.5,true)
  canvas.draw_line(end,right,Color("#594352"),width+1.5,true)
  canvas.draw_line(start,left,bond.ca,width,true)
  canvas.draw_line(end,right,bond.cb,width,true)
  var radius=2.3 if core else 5.0
  if bond.connected and bond.progress>=1:
   canvas.draw_circle(middle,radius,Color("#f5dfcb"))
   canvas.draw_arc(middle,radius*0.75,-PI/2,PI/2,12,Color("#998a87"),1,true)
  else:
   for hand in [left,right]:
    canvas.draw_circle(hand,radius*0.75,Color("#f5dfcb"))
    canvas.draw_line(hand,hand+direction.orthogonal()*radius,Color("#f5dfcb"),1.5,true)
func draw_events(canvas):
 for pulse in signals.slice(maxi(0,signals.size()-8)):
  var path=pulse.path
  var progress=clampf(pulse.age/0.65,0,1)
  var lengths=[]
  var total=0.0
  for i in range(path.size()-1):
   var length=path[i].distance_to(path[i+1])
   lengths.append(length)
   total+=length
  var remaining=total*progress
  var color=Color("#9be9ec") if pulse.kind=="transfer" else Color("#ffe79a")
  color.a=1-pulse.age/0.85
  for i in range(lengths.size()):
   var amount=minf(remaining,lengths[i])
   if amount<=0: break
   var end=path[i].lerp(path[i+1],amount/maxf(0.001,lengths[i]))
   canvas.draw_line(path[i],end,Color(color, color.a*0.45),3,true)
   if remaining<=lengths[i]: canvas.draw_circle(end,4,color)
   remaining-=lengths[i]
 var labels=0
 for hit in hits.slice(maxi(0,hits.size()-16)):
  var color=Color("#efbd58") if hit.kind=="cell" else Color("#f07887") if hit.kind in ["virus","core"] else Color("#dcebf0")
  color.a=1-hit.age/0.65
  var radius=18+hit.age*20
  canvas.draw_arc(hit.p,radius,0,TAU,40,color,2,true)
  if hit["from"].distance_to(hit.p)>1:
   var direction=hit.p.direction_to(hit["from"])
   var tip=hit.p+direction*24
   canvas.draw_polyline(PackedVector2Array([tip+direction*8+direction.orthogonal()*4,tip,tip+direction*8-direction.orthogonal()*4]),color,2,true)
  if hit.kind=="cell" and labels<3:
   labels+=1
   canvas.draw_string(ThemeDB.fallback_font,hit.p+Vector2(-16,-29-hit.age*12),"ALLY",HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
  elif hit.kind=="core":
   canvas.draw_line(hit.p+Vector2(-5,-5),hit.p+Vector2(5,5),color,2,true)
   canvas.draw_line(hit.p+Vector2(5,-5),hit.p+Vector2(-5,5),color,2,true)
