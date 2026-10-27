extends RefCounted
var states={}
var observed_sim
var revision_seen=-1
var cursor=0
var phase=""
var ray_walls=[]
var prepared_visibility=false
const WALL_CORNERS=[Vector2(-43,-13),Vector2(43,-13),Vector2(43,13),Vector2(-43,13)]
func visible(sim,origin: Vector2,target: Vector2):
 var lower=origin.min(target)-Vector2(45,45)
 var upper=origin.max(target)+Vector2(45,45)
 for c in (ray_walls if prepared_visibility else sim.cells):
  if not prepared_visibility and (not c.alive or sim.catalog[c.key].behavior!="wall"): continue
  var position: Vector2=c.p
  # A rotated 86x26 wall fits strictly inside radius 45. Reject only rays
  # whose bounds cannot reach it; retain the original edge test at boundaries.
  if position.x<lower.x or position.x>upper.x or position.y<lower.y or position.y>upper.y:continue
  var a: Vector2
  var b: Vector2
  if prepared_visibility:
   var start: Vector2=origin-position;var end: Vector2=target-position
   a=Vector2(start.dot(c.x_axis),start.dot(c.y_axis))
   b=Vector2(end.dot(c.x_axis),end.dot(c.y_axis))
  else:
   a=(origin-position).rotated(-c.angle)
   b=(target-position).rotated(-c.angle)
  if maxf(a.x,b.x)<-43 or minf(a.x,b.x)>43 or maxf(a.y,b.y)<-13 or minf(a.y,b.y)>13:continue
  if Rect2(-43,-13,86,26).has_point(a): continue
  for i in range(4):
   if Geometry2D.segment_intersects_segment(a,b,WALL_CORNERS[i],WALL_CORNERS[(i+1)%4])!=null: return false
 return true
func update(sim,delta):
 ray_walls.clear()
 for wall in sim.cells:
  if not wall.alive or sim.catalog[wall.key].behavior!="wall":continue
  var axis=Vector2.RIGHT.rotated(-wall.angle)
  ray_walls.append({"p":wall.p,"x_axis":Vector2(axis.x,-axis.y),"y_axis":Vector2(axis.y,axis.x)})
 prepared_visibility=true
 var fresh=observed_sim!=sim or revision_seen!=sim.presentation_revision
 observed_sim=sim
 revision_seen=sim.presentation_revision
 var config=sim.rules.blood_faces
 var web_targets=[]
 if sim.phase=="battle" and sim.physics.get("web_kernel")!=null:
  var origins=[];var targets=[];var walls=[]
  for b in sim.blood:origins.append([b.p.x,b.p.y])
  for v in sim.viruses:targets.append([v.p.x,v.p.y,v.alive])
  for wall in ray_walls:walls.append([wall.p.x,wall.p.y,wall.y_axis.y,wall.y_axis.x])
  web_targets=JSON.parse_string(sim.physics.web_kernel.nearestVisible(JSON.stringify([origins,targets,walls,float(config.attention_radius)],"",true,true)))
 if fresh or (phase!=sim.phase and sim.phase in ["shop","battle"]) or cursor>sim.event_sequence:
  states.clear()
  cursor=sim.event_sequence
  phase=sim.phase
 var notices=sim.events_since(cursor)
 cursor=sim.event_sequence
 for blood_index in range(sim.blood.size()):
  var b=sim.blood[blood_index]
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
  if not web_targets.is_empty():
   var index=int(web_targets[blood_index])
   if index>=0:
    nearest=sim.viruses[index];distance=b.p.distance_to(nearest.p)
  elif sim.phase=="battle":
   # Test nearer candidates first. Float32 distance and stable index tie-break
   # preserve the former nearest-visible result, while avoiding farther rays.
   var candidates: Array[Vector2]=[]
   var origin: Vector2=b.p
   for i in range(sim.viruses.size()):
    var v: Dictionary=sim.viruses[i]
    if not v.alive:continue
    var range_to: float=origin.distance_to(v.p)
    if range_to<distance:candidates.append(Vector2(range_to,i))
   candidates.sort()
   for candidate in candidates:
    var v: Dictionary=sim.viruses[int(candidate.y)]
    if visible(sim,origin,v.p):
     nearest=v;distance=candidate.x
     break
  var goal=Vector2.ZERO
  state.target=-1
  if not nearest.is_empty():
   goal=b.p.direction_to(nearest.p)
   state.target=nearest.id
   if distance<=float(config.danger_radius): state.fear=maxf(state.fear,0.2)
  state.emotion="crying" if state.cry>0 else "scared" if state.fear>0 else ("relieved" if state.relief>0 else ("surprised" if not nearest.is_empty() else "calm"))
  if sim.phase in ["recap","win","lose"] and state.cry<=0:
   state.emotion="tired" if sim.phase=="lose" or sim.round_losses.core>0 or sim.round_losses.cells>0 else "relieved"
  state.look=state.look.lerp(goal,1-exp(-delta/float(config.look_smoothing)))
  states[b.id]=state
 prepared_visibility=false
var batch_tears=false
var tear_lines=PackedVector2Array()
var tear_drops: Array[Vector2]=[]
func begin_draw():
 batch_tears=true;tear_lines.clear();tear_drops.clear()
func finish_draw(canvas):
 if not tear_lines.is_empty():canvas.draw_multiline(tear_lines,Color("#92dcef"),1.5,true)
 for drop in tear_drops:part(canvas,14,drop)
 batch_tears=false
const FACE_PARTS=preload("res://assets/ui/core-face-parts.svg")
const EMOTIONS=["calm","surprised","scared","relieved","tired","crying","blink"]
func part(canvas,index,p):
 canvas.draw_texture_rect_region(FACE_PARTS,Rect2(p-Vector2(16,16),Vector2(32,32)),Rect2(Vector2(index%8,index/8)*256,Vector2(256,256)))
func draw(canvas,b,time):
 var s=states.get(b.id,{"look":Vector2.ZERO,"emotion":"calm"})
 var p: Vector2=b.p
 var look: Vector2=s.look*2.2
 var emotion: String=s.emotion
 var blink=fmod(time+b.id*0.71,4.8)<0.14
 part(canvas,6 if blink and emotion=="calm" else maxi(0,EMOTIONS.find(emotion)),p)
 if emotion in ["calm","surprised","scared"] and not (blink and emotion=="calm"):
  for side in [-1,1]:part(canvas,7,p+Vector2(side*3.8,-1.5)+look*0.55)
 var mouth=p+Vector2(0,4.5)+look*0.3
 var mouth_index=8 if emotion=="crying" else (9 if emotion=="tired" else (10 if emotion=="surprised" else (11 if emotion=="scared" else 12)))
 part(canvas,mouth_index,mouth)
 if emotion=="crying":
  for side in [-1,1]:
   var eye=p+Vector2(side*3.8,-1.5)
   var drop=eye+Vector2(side*0.7,3+fmod(time*7+b.id*0.8,5.0))
   if batch_tears:
    tear_lines.append(eye+Vector2(0,1));tear_lines.append(drop);tear_drops.append(drop)
   else:
    canvas.draw_line(eye+Vector2(0,1),drop,Color("#92dcef"),1.5,true)
    canvas.draw_circle(drop,1.5,Color("#b9efff"))
