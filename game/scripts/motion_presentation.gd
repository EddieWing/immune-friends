extends RefCounted
# Cosmetic water pressure reads physical velocity; it never drives a body.
var observed_sim
var revision=-1
var previous_time=0.0
var samples={}
var modes={}
var wakes=[]
var cilia={}
var arcs=preload("res://scripts/arc_batch.gd").new()
func update(sim,delta=0.0):
 var fresh: bool=observed_sim!=sim or revision!=sim.presentation_revision or sim.elapsed<previous_time
 if fresh:
  samples.clear()
  modes.clear()
  cilia.clear()
 observed_sim=sim
 revision=sim.presentation_revision
 var dt: float=maxf(0,sim.elapsed-previous_time) if not fresh else 0.0
 previous_time=sim.elapsed
 var living_core={}
 var blend: float=1-exp(-(dt if sim.phase=="battle" else delta)/0.18)
 for b: Dictionary in sim.blood:
  if not b.alive:continue
  living_core[b.id]=true
  var velocity: Vector2=sim.physics.states.get(sim.physics.id_of(b),{}).get("v",Vector2.ZERO)
  var speed: float=velocity.length()
  var strength: float=clampf(speed/70.0,0,1)
  cilia[b.id]=lerpf(cilia.get(b.id,0.0),strength,blend)
 for id in cilia.keys():
  if not living_core.has(id):cilia.erase(id)
 wakes.clear()
 if sim.phase!="battle":
  samples.clear()
  modes.clear()
  return
 var alive={}
 for bodies: Array in [sim.cells,sim.viruses]:
  for body: Dictionary in bodies:
   if not body.alive: continue
   var id: int=sim.physics.id_of(body)
   alive[id]=true
   # state()/velocity() would create missing physical state as a side effect.
   var velocity: Vector2=sim.physics.states.get(id,{}).get("v",Vector2.ZERO)
   var previous: Vector2=samples.get(id,velocity)
   var acceleration: Vector2=(velocity-previous)/dt if dt>0 else Vector2.ZERO
   if dt>0 or not samples.has(id): samples[id]=velocity
   var speed: float=velocity.length()
   if speed<3 or body.get("freeze",0)>0 or body.get("emerging",false): continue
   var direction: Vector2=velocity.normalized()
   var strength: float=clampf(speed/140.0,0.0,1.0)
   var mode: String=modes.get(id,"glide")
   if dt>0:
    mode="glide"
    var forward_acceleration: float=acceleration.dot(direction)
    if forward_acceleration>12: mode="accelerate"
    elif forward_acceleration< -12: mode="brake"
    modes[id]=mode
   var radius: float=26.0 if body.has("key") else 18.0
   # Walls keep their physical long axis; the pressure ring must clear the end.
   if body.has("key") and sim.catalog[body.key].behavior=="wall": radius=46.0
   var wake={"id":id,"p":body.p,"direction":direction,"strength":strength,"mode":mode,"radius":radius}
   if body.get("type","")=="wave":
    var forward: Vector2=body.get("wave_direction",body.get("visual_heading",Vector2.RIGHT)).normalized()
    var lateral: float=velocity.dot(forward.orthogonal())
    wake.wave_side=forward.orthogonal()*signf(lateral)
    wake.wave_strength=clampf(absf(lateral)/100.0,0,1)
   wakes.append(wake)
 for id in samples.keys():
  if not alive.has(id):
   samples.erase(id)
   modes.erase(id)
func cilia_tints(id,tips:PackedVector2Array,time:float)->PackedColorArray:
 # The light and strength are shared by all hairs on this Core cell.
 # Keep the original normal division and color interpolation order.
 var colors=PackedColorArray()
 var light=Vector2.from_angle(time*0.12-PI*0.6)
 var strength=cilia.get(id,0.0)*0.32
 var low=Color("#b96b82");var high=Color("#e6b6c7")
 for tip in tips:
  var normal=tip/13.0
  var highlight=maxf(0,normal.dot(light))*0.12
  colors.append(low.lerp(high,strength+highlight))
 return colors
func cilia_tint(id,normal,time):
 var strength=cilia.get(id,0.0)
 var light=Vector2.from_angle(time*0.12-PI*0.6)
 var highlight=maxf(0,normal.dot(light))*0.12
 return Color("#b96b82").lerp(Color("#e6b6c7"),strength*0.32+highlight)
func draw(canvas):
 arcs.begin()
 for wake in wakes:
  var angle=wake.direction.angle()+PI
  var strength=wake.strength
  var tint=Color(0.85,0.98,1,0.18+strength*0.22)
  arcs.add(wake.p,wake.radius+strength*3,angle,0.8,tint)
  if wake.mode=="accelerate":
   tint.a*=0.5
   arcs.add(wake.p,wake.radius+6+strength*5,angle,0.56,tint)
  elif wake.mode=="brake":
   tint.a*=0.7
   arcs.add(wake.p,wake.radius,angle+PI,0.6,tint)
  if wake.get("wave_strength",0)>0.03:
   # The visible side follows lateral velocity, not the phase of the drive force.
   # Inertia can keep the body moving sideways after its drive has reversed.
   var side_angle=wake.wave_side.angle()
   arcs.add(wake.p,21,side_angle,1.2,Color(0.58,0.43,0.75,0.15+wake.wave_strength*0.3))
 arcs.flush(canvas)
