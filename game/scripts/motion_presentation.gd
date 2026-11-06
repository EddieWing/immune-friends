extends RefCounted
# Cosmetic water pressure reads physical velocity; it never drives a body.
var observed_sim
var revision=-1
var previous_time=0.0
var samples={}
var wakes=[]
var cilia={}
func update(sim,delta=0.0):
 var fresh=observed_sim!=sim or revision!=sim.presentation_revision or sim.elapsed<previous_time
 if fresh:
  samples.clear()
  cilia.clear()
 observed_sim=sim
 revision=sim.presentation_revision
 var dt=maxf(0,sim.elapsed-previous_time) if not fresh else 0.0
 previous_time=sim.elapsed
 var living_core={}
 for b in sim.blood:
  if not b.alive:continue
  living_core[b.id]=true
  var speed=sim.physics.states.get(sim.physics.id_of(b),{}).get("v",Vector2.ZERO).length()
  var strength=clampf(speed/70.0,0,1)
  var blend=1-exp(-(dt if sim.phase=="battle" else delta)/0.18)
  cilia[b.id]=lerpf(cilia.get(b.id,0.0),strength,blend)
 for id in cilia.keys():
  if not living_core.has(id):cilia.erase(id)
 wakes.clear()
 if sim.phase!="battle":
  samples.clear()
  return
 var alive={}
 for bodies in [sim.cells,sim.viruses]:
  for body in bodies:
   if not body.alive: continue
   var id=sim.physics.id_of(body)
   alive[id]=true
   # state()/velocity() would create missing physical state as a side effect.
   var velocity=sim.physics.states.get(id,{}).get("v",Vector2.ZERO)
   var previous=samples.get(id,velocity)
   var acceleration=(velocity-previous)/dt if dt>0 else Vector2.ZERO
   if dt>0 or not samples.has(id): samples[id]=velocity
   if velocity.length()<3 or body.get("freeze",0)>0 or body.get("emerging",false): continue
   var speed=velocity.length()
   var strength=clampf(speed/140.0,0.0,1.0)
   var mode="glide"
   if acceleration.dot(velocity.normalized())>12: mode="accelerate"
   elif acceleration.dot(velocity.normalized())< -12: mode="brake"
   var radius=26.0 if body.has("key") else 18.0
   # Walls keep their physical long axis; the pressure ring must clear the end.
   if body.has("key") and sim.catalog[body.key].behavior=="wall": radius=46.0
   wakes.append({"id":id,"p":body.p,"direction":velocity.normalized(),"strength":strength,"mode":mode,"radius":radius})
 for id in samples.keys():
  if not alive.has(id): samples.erase(id)
func cilia_tint(id,normal,time):
 var strength=cilia.get(id,0.0)
 var light=Vector2.from_angle(time*0.12-PI*0.6)
 var highlight=maxf(0,normal.dot(light))*0.12
 return Color("#b96b82").lerp(Color("#e6b6c7"),strength*0.32+highlight)
func draw(canvas):
 for wake in wakes:
  var angle=wake.direction.angle()+PI
  var strength=wake.strength
  var tint=Color(0.85,0.98,1,0.18+strength*0.22)
  canvas.draw_arc(wake.p,wake.radius+strength*3,angle-0.40,angle+0.40,8,tint,1.2,true)
  if wake.mode=="accelerate":
   tint.a*=0.5
   canvas.draw_arc(wake.p,wake.radius+6+strength*5,angle-0.28,angle+0.28,8,tint,1.0,true)
  elif wake.mode=="brake":
   tint.a*=0.7
   canvas.draw_arc(wake.p,wake.radius,angle+PI-0.3,angle+PI+0.3,8,tint,1.0,true)
