extends RefCounted
var observed_sim
var round_seen=-1
var phase_seen=""
var elapsed=0.0
var cursor=0
var feeding={}
var looks={}
var effects=[]
var attachments=[]
func update(sim,delta):
 if observed_sim!=sim or round_seen!=sim.round_no or cursor>sim.events.size() or sim.elapsed<elapsed or (sim.phase=="battle" and phase_seen!="battle"):
  feeding.clear()
  looks.clear()
  effects.clear()
  cursor=0 if sim.phase=="battle" else sim.events.size()
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
 for event in sim.events.slice(cursor):
  if event.event in ["virus_fed","virus_attachment","virus_target"]:
   var e=event.data.duplicate()
   e.kind=event.event
   e.age=0.0
   effects.append(e)
   if event.event=="virus_fed": feeding[e.id]=0.55
 cursor=sim.events.size()
 if effects.size()>32: effects=effects.slice(effects.size()-32)
 var alive={}
 for v in sim.viruses:
  if v.alive: alive[v.id]=v
 for id in looks.keys():
  if not alive.has(id): looks.erase(id)
 attachments=[]
 for v in alive.values():
  var goal=v.get("visual_heading",Vector2.ZERO)
  if v.get("emerging",false): goal=v.p.direction_to(v.exit)
  looks[v.id]=looks.get(v.id,Vector2.ZERO).lerp(goal,1-exp(-dt/0.14))
  if v.type=="swarmer" and alive.has(v.get("host",-1)):
   attachments.append({"a":v.p,"b":alive[v.host].p})
func scale_of(id):
 return 1+sin((1-feeding.get(id,0.0)/0.55)*PI)*0.13 if feeding.has(id) else 1.0
func draw_links(canvas):
 for link in attachments:
  var d=link.a.direction_to(link.b)
  var middle=(link.a+link.b)*0.5
  canvas.draw_line(link.a+d*8,link.b-d*8,Color("#745179"),2,true)
  for side in [-1,1]:
   var p=middle+d.orthogonal()*side*3
   canvas.draw_polyline(PackedVector2Array([p-d*3,p,p+d*3+d.orthogonal()*side*2]),Color("#d5a4d4"),1.5,true)
func draw_effects(canvas):
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
