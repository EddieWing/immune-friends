extends RefCounted
# Cosmetic anticipation reads existing cooldowns; only real attacks trigger recoil.
const WINDUP=0.30
const RECOVERY=0.32
var observed_sim
var previous_time=0.0
var previous_phase=""
var previous_round=-1
var cursor=0
var recoil={}
var poses={}
var focus={}
var focus_cooldown=0.0
func update(sim,delta):
 if observed_sim!=sim or previous_round!=sim.round_no or sim.elapsed<previous_time or (sim.phase=="battle" and previous_phase!="battle"):
  cursor=0 if sim.phase=="battle" else sim.events.size()
  recoil.clear()
  poses.clear()
  focus={}
  focus_cooldown=0.0
  previous_time=sim.elapsed
 observed_sim=sim
 previous_round=sim.round_no
 var dt=maxf(0,sim.elapsed-previous_time) if sim.phase=="battle" else delta
 previous_time=sim.elapsed
 previous_phase=sim.phase
 focus_cooldown=maxf(0,focus_cooldown-dt)
 if not focus.is_empty():
  focus.age+=dt
  if focus.age>=0.85: focus={}
 for id in recoil.keys():
  recoil[id].age+=dt
  if recoil[id].age>=RECOVERY: recoil.erase(id)
 for event in sim.events.slice(cursor):
  var data=event.data
  if event.event=="attack_fired" and data.key in ["cannon","sniper","pusher"]:
   recoil[data.id]={"age":0.0,"direction":data.direction}
  elif event.event=="virus_defeated" and data.get("key_threat",false) and focus_cooldown<=0:
   focus={"p":data.p,"age":0.0}
   focus_cooldown=1.2
 cursor=sim.events.size()
 poses.clear()
 if sim.phase!="battle": return
 for c in sim.cells:
  if not c.alive or c.key not in ["cannon","sniper","pusher"]: continue
  var pose={"windup":0.0,"kick":0.0,"look":Vector2.ZERO,"direction":Vector2.RIGHT.rotated(c.angle),"radial":c.key=="pusher"}
  var target=aim_target(sim,c)
  var ready=c.key=="pusher" or not target.is_empty()
  if not target.is_empty():
   pose.direction=c.p.direction_to(target.p)
   pose.look=pose.direction*1.6
  if ready and c.cool>0 and c.cool<=WINDUP:
   pose.windup=1-clampf(c.cool/WINDUP,0,1)
  if recoil.has(c.id):
   pose.kick=1-smoothstep(0,RECOVERY,recoil[c.id].age)
   pose.direction=recoil[c.id].direction
  poses[c.id]=pose
func aim_target(sim,c):
 var reach=sim.range_of(c)
 if c.key=="sniper":
  var direction=Vector2.RIGHT.rotated(c.angle)
  for v in sim.viruses:
   if v.alive and c.p.distance_to(v.p)<reach and absf(direction.angle_to(v.p-c.p))<0.20: return v
  return {}
 if c.key!="cannon": return {}
 var target=sim.nearest_virus(c.p,reach)
 if target.is_empty():
  for v in sim.viruses:
   if v.alive and v.tag>0 and c.p.distance_to(v.p)<reach*2: return v
 return target
func jumper_pose(v):
 if v.type!="jumper" or v.get("emerging",false) or v.get("freeze",0)>0: return 0.0
 var cycle=fposmod(v.get("age",0)+v.get("phase",0),3.5)
 return clampf((cycle-2.5)/0.3,0,1) if cycle<=2.8 else 0.0
func jumper_recovery(v):
 if v.type!="jumper" or v.get("emerging",false) or v.get("freeze",0)>0 or v.get("age",0)<0.2: return 0.0
 var cycle=fposmod(v.get("age",0)+v.get("phase",0),3.5)
 return 1-smoothstep(0,0.2,cycle) if cycle<0.2 else 0.0
func draw_intent(canvas,c):
 var pose=poses.get(c.id,{})
 if pose.is_empty() or pose.windup<=0: return
 var alpha=pose.windup*0.85
 var color=Color(1,0.85,0.46,alpha)
 var radius=24-pose.windup*4
 if pose.radial:
  for i in range(8):
   var d=Vector2.from_angle(i*TAU/8)
   canvas.draw_line(c.p+d*radius,c.p+d*(radius+5),color,2,true)
 else:
  var tip=c.p+pose.direction*radius
  canvas.draw_circle(tip,2+pose.windup*2,color)
  canvas.draw_line(tip,tip+pose.direction*10,color,2,true)
func draw_focus(canvas):
 if focus.is_empty(): return
 var progress=focus.age/0.85
 var color=Color(0.83,1,0.83,1-progress)
 var r=22+progress*22
 for i in range(4):
  var a=i*PI/2+PI/4
  canvas.draw_arc(focus.p,r,a-0.18,a+0.18,10,Color(0.13,0.32,0.30,color.a),5,true)
  canvas.draw_arc(focus.p,r,a-0.18,a+0.18,10,color,2.5,true)
 canvas.draw_string(ThemeDB.fallback_font,focus.p+Vector2(-48,-38-progress*12),"THREAT CLEARED",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.13,0.32,0.30,color.a))
