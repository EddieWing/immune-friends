extends RefCounted
var observed_sim
var cursor=0
var elapsed=0.0
var phase_seen=""
var active={}
var links={}
var cooldowns={}
var clock=0.0
func update(sim,delta,faces):
 if observed_sim!=sim or cursor>sim.events.size() or sim.elapsed<elapsed:
  cursor=sim.events.size()
  links.clear()
  active={}
  cooldowns.clear()
  elapsed=sim.elapsed
 observed_sim=sim
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 elapsed=sim.elapsed
 clock+=dt
 if not active.is_empty():
  active.age+=dt
  if active.age>=1.0: active={}
 var candidates=[]
 var losses=[]
 for event in sim.events.slice(cursor):
  if event.event=="blood_lost": losses.append(event.data.p)
  elif event.event=="virus_defeated" and event.data.get("key_threat",false):
   candidates.append({"priority":1,"kind":"cleared","p":event.data.p,"text":"THREAT CLEARED"})
 cursor=sim.events.size()
 if not losses.is_empty():
  candidates.append({"priority":4,"kind":"loss","p":losses[0],"text":"CORE LOST"+(" x%d" % losses.size() if losses.size()>1 else "")})
 var current_links={}
 if sim.phase=="battle":
  for link in sim.links:
   var a=sim.cell_by_id(link.a)
   var b=sim.cell_by_id(link.b)
   if a.is_empty() or b.is_empty() or not a.alive or not b.alive: continue
   var key="cell:%d:%d" % [mini(a.id,b.id),maxi(a.id,b.id)]
   current_links[key]=(a.p+b.p)*0.5
  for link in sim.blood_links:
   var a=sim.blood[link.a]
   var b=sim.blood[link.b]
   if a.alive and b.alive: current_links["core:%d:%d" % [link.a,link.b]]=(a.p+b.p)*0.5
  if phase_seen=="battle":
   for key in links:
    if not current_links.has(key):
     candidates.append({"priority":2,"kind":"link","p":links[key],"text":"BOND BROKEN"})
     break
  var nearest=float(sim.rules.blood_faces.danger_radius)
  var threatened={}
  for core in sim.blood:
   if not core.alive: continue
   for v in sim.viruses:
    var distance=core.p.distance_to(v.p)
    if v.alive and distance<nearest and faces.visible(sim,core.p,v.p):
     nearest=distance
     threatened=core
  if not threatened.is_empty(): candidates.append({"priority":3,"kind":"danger","p":threatened.p,"text":"CORE AT RISK"})
 links=current_links
 phase_seen=sim.phase
 candidates.sort_custom(func(a,b): return a.priority>b.priority)
 for candidate in candidates:
  if not active.is_empty() and candidate.priority<=active.priority: continue
  if candidate.kind!="loss" and clock<cooldowns.get(candidate.kind,-1): break
  candidate.age=0.0
  active=candidate
  cooldowns[candidate.kind]=clock+(2.5 if candidate.kind=="danger" else 1.2)
  break
func draw(canvas):
 if active.is_empty(): return
 var t=active.age
 var color=Color("#f2868c") if active.priority>=3 else Color("#efc571") if active.priority==2 else Color("#c5efd2")
 color.a=1-t
 var r=24+t*12
 for i in range(4):
  var angle=i*PI/2+PI/4
  canvas.draw_arc(active.p,r,angle-0.2,angle+0.2,12,Color(0.15,0.2,0.25,1-t),4,true)
  canvas.draw_arc(active.p,r,angle-0.2,angle+0.2,12,color,2,true)
 var width=ThemeDB.fallback_font.get_string_size(active.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
 var p=active.p+Vector2(-width/2,-42-t*8)
 canvas.draw_style_box(label_style(Color(0.13,0.18,0.23,(1-t)*0.88)),Rect2(p+Vector2(-5,-13),Vector2(width+10,19)))
 canvas.draw_string(ThemeDB.fallback_font,p,active.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
func label_style(color):
 var style=StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(4)
 return style
