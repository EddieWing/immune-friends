extends RefCounted
var revision_seen=-1
var observed_sim
var round_seen=-1
var phase_seen=""
var elapsed=0.0
var cursor=0
var feeding={}
var looks={}
var effects=[]
var attachments=[]
var suspended={}
var tagged={}
var motion=preload("res://scripts/motion_presentation.gd").new()
func update(sim,delta):
 motion.update(sim,delta)
 var fresh=observed_sim!=sim or revision_seen!=sim.presentation_revision
 revision_seen=sim.presentation_revision
 if fresh or round_seen!=sim.round_no or cursor>sim.event_sequence or sim.elapsed<elapsed or (sim.phase=="battle" and phase_seen!="battle"):
  feeding.clear()
  looks.clear()
  effects.clear()
  cursor=sim.event_sequence if fresh else cursor
  elapsed=sim.elapsed
 observed_sim=sim
 round_seen=sim.round_no
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 elapsed=sim.elapsed
 phase_seen=sim.phase
 for id in feeding.keys():
  feeding[id]-=dt
  if feeding[id]<=0: feeding.erase(id)
 for effect in effects: effect.age+=dt
 effects=effects.filter(func(e): return e.age<0.65)
 for event in sim.events_since(cursor):
  if event.event in ["virus_fed","virus_attachment","virus_target"]:
   var e=event.data.duplicate()
   e.kind=event.event
   e.age=0.0
   effects.append(e)
   if event.event=="virus_fed": feeding[e.id]=0.55
 cursor=sim.event_sequence
 if effects.size()>32: effects=effects.slice(effects.size()-32)
 var alive={}
 suspended.clear()
 tagged.clear()
 for v: Dictionary in sim.viruses:
  if v.alive:
   alive[v.id]=v
   if float(v.get("freeze",0))>0:
    suspended[v.id]={"p":v.p,"remaining":float(v.freeze)}
   if float(v.get("tag",0))>0: tagged[v.id]=v.p
 for id in looks.keys():
  if not alive.has(id): looks.erase(id)
 attachments=[]
 var look_blend: float=1-exp(-dt/0.14)
 for v: Dictionary in alive.values():
  var goal: Vector2=v.get("visual_heading",Vector2.ZERO)
  if v.get("emerging",false): goal=v.p.direction_to(v.exit)
  var previous_look: Vector2=looks.get(v.id,Vector2.ZERO)
  looks[v.id]=previous_look.lerp(goal,look_blend)
 for link in sim.links:
  if link.get("swarm",false) and alive.has(link.a) and alive.has(link.b):
   attachments.append({"a":alive[link.a].p,"b":alive[link.b].p})
func scale_of(id):
 return 1+sin((1-feeding.get(id,0.0)/0.55)*PI)*0.13 if feeding.has(id) else 1.0
func spawn_alpha(v):
 # Appearance follows the actor's real lifetime, never delays its collision/motion.
 if observed_sim!=null and observed_sim.phase!="battle":return 1.0
 if v.get("emerging",false):
  var distance=v.get("spawn_position",v.p).distance_to(v.get("exit",v.p))
  return lerpf(0.25,1.0,clampf(v.get("spawn_position",v.p).distance_to(v.p)/maxf(1,distance),0,1))
 return lerpf(0.25,1.0,smoothstep(0,0.35,float(v.get("age",1.0))))
func draw_links(canvas):
 for link in attachments:
  var d=link.a.direction_to(link.b)
  var middle=(link.a+link.b)*0.5
  canvas.draw_line(link.a+d*8,link.b-d*8,Color("#745179"),2,true)
  for side in [-1,1]:
   var p=middle+d.orthogonal()*side*3
   canvas.draw_polyline(PackedVector2Array([p-d*3,p,p+d*3+d.orthogonal()*side*2]),Color("#d5a4d4"),1.5,true)
func draw_effects(canvas):
 motion.draw(canvas)
 # Tag persists after suspend ends; show it in either graphics theme.
 for p in tagged.values():
  canvas.draw_arc(p,17,0,TAU,24,Color("#f4c5d9"),1.5,true)
  canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-25),p+Vector2(3,-21),p+Vector2(0,-17),p+Vector2(-3,-21)]),Color("#e894c1"))
 # This is a status indicator, not a speed test: blocked collisions are not suspend.
 # Shared by both field styles and driven directly by the mechanical timer.
 for status in suspended.values():
  var p=status.p
  canvas.draw_circle(p,22,Color(0.55,0.86,0.95,0.12))
  canvas.draw_arc(p,22,0,TAU,28,Color(0.35,0.65,0.8,0.9),1.5,true)
  var badge=p+Vector2(19,-18)
  canvas.draw_circle(badge,6,Color("#234857"))
  for x in [-2,2]:
   canvas.draw_line(badge+Vector2(x,-3),badge+Vector2(x,3),Color("#d4f8ff"),1.5,true)
 for e in effects.slice(maxi(0,effects.size()-10)):
  var t=e.age/0.65
  var color=Color(0.92,0.7,0.91,1-t)
  if e.kind=="virus_fed":
   canvas.draw_circle(e["from"].lerp(e.p,minf(1,t*2)),3*(1-t),Color(0.98,0.82,0.43,1-t))
   canvas.draw_string(ThemeDB.fallback_font,e.p+Vector2(-15,-24-t*10),"+1 HP",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.4,0.22,0.38,1-t))
  elif e.kind=="virus_attachment":
   var r=17+t*8
   for side in [-1,1]:
    var p=e.p+Vector2(side*r,0)
    canvas.draw_polyline(PackedVector2Array([p+Vector2(-side*3,-4),p,p+Vector2(-side*3,4)]),color,2,true)
  else:
   var d=e.p.direction_to(e.target)
   canvas.draw_arc(e.p,20+t*4,d.angle()-0.3,d.angle()+0.3,12,color,2,true)
