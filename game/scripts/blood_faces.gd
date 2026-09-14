extends RefCounted
var states={}
var cursor=0
var phase=""
func visible(sim,origin,target):
 for c in sim.cells:
  if not c.alive or sim.catalog[c.key].behavior!="wall": continue
  var a=(origin-c.p).rotated(-c.angle)
  var b=(target-c.p).rotated(-c.angle)
  var corners=[Vector2(-43,-13),Vector2(43,-13),Vector2(43,13),Vector2(-43,13)]
  if Rect2(-43,-13,86,26).has_point(a): continue
  for i in range(4):
   if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return false
 return true
func update(sim,delta):
 var config=sim.rules.blood_faces
 if (phase!=sim.phase and sim.phase in ["shop","battle"]) or cursor>sim.events.size():
  states.clear()
  cursor=sim.events.size()
  phase=sim.phase
 var notices=sim.events.slice(cursor)
 cursor=sim.events.size()
 for b in sim.blood:
  if not b.alive: states.erase(b.id); continue
  var state=states.get(b.id,{"look":Vector2.ZERO,"target":-1,"emotion":"calm","fear":0.0,"relief":0.0,"cry":0.0})
  state.cry=maxf(0,state.get("cry",0.0)-delta)
  state.fear=maxf(0,state.fear-delta)
  state.relief=maxf(0,state.relief-delta)
  if sim.phase in ["battle","recap","win","lose"]:
   for e in notices:
    var d=e.data
    if e.event=="blood_lost" and b.id in d.get("hand_neighbors",[]): state.cry=float(config.get("cry_seconds",3.0))
    if not d.has("p"): continue
    if e.event in ["cell_rest","blood_lost"] and b.p.distance_to(d.p)<=float(config.attention_radius) and visible(sim,b.p,d.p): state.fear=float(config.fear_seconds)
    if e.event=="virus_defeated" and d.get("id",-2)==state.target: state.relief=float(config.relief_seconds)
  var nearest={}
  var distance=float(config.attention_radius)
  if sim.phase=="battle":
   for v in sim.viruses:
    var range_to=b.p.distance_to(v.p)
    if v.alive and range_to<distance and visible(sim,b.p,v.p): nearest=v; distance=range_to
  var goal=Vector2.ZERO
  state.target=-1
  if not nearest.is_empty():
   goal=b.p.direction_to(nearest.p)
   state.target=nearest.id
   if distance<=float(config.danger_radius): state.fear=maxf(state.fear,0.2)
  state.emotion="crying" if state.cry>0 else "scared" if state.fear>0 else ("relieved" if state.relief>0 else ("surprised" if not nearest.is_empty() else "calm"))
  state.look=state.look.lerp(goal,1-exp(-delta/float(config.look_smoothing)))
  states[b.id]=state
func draw(canvas,b,time):
 var s=states.get(b.id,{"look":Vector2.ZERO,"emotion":"calm"})
 var p=b.p
 var look=s.look*2.2
 var ink=Color("#483546")
 var emotion=s.emotion
 var blink=fmod(time+b.id*0.71,4.8)<0.14
 for side in [-1,1]:
  var eye=p+Vector2(side*3.8,-1.5)
  if emotion=="crying":
   canvas.draw_arc(eye+Vector2(0,1),1.7,PI+0.15,TAU-0.15,12,ink,1.3,true)
   var drop=eye+Vector2(side*0.7,3+fmod(time*7+b.id*0.8,5.0))
   canvas.draw_line(eye+Vector2(0,1),drop,Color("#92dcef"),1.5,true)
   canvas.draw_circle(drop,1.5,Color("#b9efff"))
  elif emotion=="relieved" or (blink and emotion=="calm"):
   canvas.draw_arc(eye,1.5,0.1,PI-0.1,10,ink,1.2,true)
  else:
   var radius=2.4 if emotion in ["surprised","scared"] else 1.8
   canvas.draw_circle(eye,radius,Color("#fff1df"))
   canvas.draw_circle(eye+look*0.55,1.0,ink)
  if emotion=="scared": canvas.draw_line(eye+Vector2(-1.7,-3),eye+Vector2(1.7,-3-side),ink,1,true)
 var mouth=p+Vector2(0,4.5)+look*0.3
 if emotion=="crying":
  canvas.draw_arc(mouth+Vector2(0,1),2.3,PI+0.15,TAU-0.15,12,ink,1.2,true)
 elif emotion in ["surprised","scared"]:
  canvas.draw_circle(mouth,2.3 if emotion=="scared" else 1.6,ink)
 else:
  canvas.draw_arc(mouth-Vector2(0,1),2.3,0.1,PI-0.1,12,ink,1.1,true)
 if emotion=="scared": canvas.draw_circle(p+Vector2(8,-4),1.5,Color("#acdff0"))
