extends RefCounted
const MOVE_SECONDS=0.70
var revision_seen=-1
var observed_sim
var seed_seen=-1
var round_seen=-1
var states={}
var clock=0.0
func update(sim,wave,positions,stage,delta):
 if revision_seen!=sim.presentation_revision or observed_sim!=sim or seed_seen!=sim.seed_value or sim.round_no<round_seen:
  states.clear()
 revision_seen=sim.presentation_revision
 observed_sim=sim
 seed_seen=sim.seed_value
 round_seen=sim.round_no
 clock+=delta
 var active={}
 for entry in wave:
  if entry.lane<0 or entry.lane>=positions.size(): continue
  if not active.has(entry.lane): active[entry.lane]={}
  active[entry.lane][entry.type]=active[entry.lane].get(entry.type,0)+entry.count
 for lane in active:
  var target=positions[lane]
  if not states.has(lane):
   states[lane]={"p":target,"from":target,"target":target,"move":1.0,"alpha":0.0,"opening":0.0,"threat":active[lane].duplicate(),"surge":1.0,"active":true}
  var s=states[lane]
  s.active=true
  if not s.target.is_equal_approx(target):
   s["from"]=s.p
   s.target=target
   s.move=0.0
  var stronger=false
  for kind in active[lane]:
   if active[lane][kind]>s.threat.get(kind,0): stronger=true
  if stronger: s.surge=1.0
  s.threat=active[lane].duplicate()
 for lane in states.keys():
  var s=states[lane]
  s.active=active.has(lane)
  s.alpha=move_toward(s.alpha,1.0 if s.active else 0.0,delta/0.55)
  if not s.active and s.alpha==0:
   states.erase(lane)
   continue
  s.move=minf(1,s.move+delta/MOVE_SECONDS)
  s.p=s["from"].lerp(s.target,smoothstep(0,1,s.move))
  s.surge=maxf(0,s.surge-delta/1.1)
  var emitting=false
  if sim.phase=="battle" and s.active:
   emitting=stage=="launch" or sim.spawn_queue.any(func(e): return e.lane==lane)
   if not emitting:
    emitting=sim.viruses.any(func(v): return v.alive and v.get("emerging",false) and v.get("source_lane",-1)==lane)
  s.opening=move_toward(s.opening,1.0 if emitting else 0.0,delta/0.65)
func draw(canvas,lane):
 var s=states[lane]
 var center=s.p
 var openness=s.opening
 var alpha=s.alpha
 # Several translucent eddies, with water visible between them; no opaque center disc.
 for petal in range(7):
  var angle=petal*TAU/7+lane*0.4+sin(clock*0.25+petal)*0.15
  var direction=Vector2.from_angle(angle)
  var offset=direction*(8+openness*18)
  for layer in range(3):
   var points=PackedVector2Array()
   for i in range(40):
    var a=i*TAU/40
    var radius=(24-layer*5)*(1+sin(a*3+clock*0.7+petal)*0.14)
    var point=Vector2(cos(a)*radius*1.3,sin(a)*radius*0.8).rotated(angle)
    points.append(center+offset+point)
   canvas.draw_colored_polygon(points,Color(0.32,0.19,0.40,(0.035+layer*0.016)*alpha))
  var trail=PackedVector2Array()
  for i in range(24):
   var t=i/23.0
   var radius=12+t*(43+openness*15)
   trail.append(center+Vector2.from_angle(angle+sin(t*4-clock*0.5+petal)*0.25)*radius)
  canvas.draw_polyline(trail,Color(0.48,0.28,0.55,0.14*alpha),3,true)
 if openness>0:
  for i in range(10):
   var t=fposmod(clock*0.5+i/10.0,1.0)
   var a=i*2.4+lane
   var p=center+Vector2.from_angle(a+sin(t*3+a)*0.2)*(8+t*45)
   canvas.draw_circle(p,2+3*t,Color(0.53,0.31,0.62,(1-t)*0.22*openness*alpha))
 if s.surge>0:
  var progress=1-s.surge
  for i in range(3):
   var r=30+progress*45+i*7
   canvas.draw_arc(center,r,0,TAU,64,Color(0.74,0.35,0.72,s.surge*alpha*(0.6-i*0.12)),2,true)
  canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-35,-72-progress*12),"THREAT RISING",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.34,0.16,0.4,s.surge*alpha))
