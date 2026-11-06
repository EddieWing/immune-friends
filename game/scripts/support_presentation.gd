extends RefCounted
var revision_seen=-1
var observed_sim
var elapsed=0.0
var cursor=0
var effects=[]
var buffs={}
var readiness={}
var waves=preload("res://scripts/wave_presentation.gd").new()
func update(sim,delta):
 waves.update(sim,delta)
 var fresh=observed_sim!=sim or revision_seen!=sim.presentation_revision
 revision_seen=sim.presentation_revision
 if fresh or cursor>sim.event_sequence:
  effects.clear()
  buffs.clear()
  if fresh: cursor=sim.event_sequence
  elapsed=sim.elapsed
 observed_sim=sim
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 if sim.elapsed<elapsed:
  effects.clear()
  buffs.clear()
 elapsed=sim.elapsed
 for effect in effects: effect.age+=dt
 effects=effects.filter(func(e): return e.age<e.life)
 for event in sim.events_since(cursor):
  if event.event in ["heal","generator_fed","generator_charged","swap","bullet_split","accelerated","attack_fired","merge","purchase_buff","cell_target","cell_return","interferon_created"] and event.data.has("p"):
   if event.event=="heal" and float(event.data.get("amount",0))<=0: continue
   if event.event=="attack_fired" and event.data.get("direction",Vector2.ZERO).length_squared()<0.001: continue
   var e=event.data.duplicate()
   e.kind=event.event
   e.age=0.0
   e.life=1.1 if e.kind=="swap" else 0.65
   if e.kind=="cell_target" and int(e.get("target_id",-1))>=0:
    effects=effects.filter(func(old):return old.kind!="cell_return" or old.id!=e.id)
   effects.append(e)
 cursor=sim.event_sequence
 # Keep a healing flash on its recipient while the physical body moves.
 for e in effects:
  if e.kind!="heal": continue
  var recipient=sim.cell_by_id(e.id)
  if recipient.is_empty() or not recipient.alive: e.age=e.life
  else: e.p=recipient.p
 effects=effects.filter(func(e): return e.age<e.life)
 var active={}
 readiness.clear()
 for c in sim.cells:
  if not c.alive: continue
  active[c.id]=true
  if sim.phase=="battle":
   var progress=readiness_of(sim,c)
   if not progress.is_empty(): readiness[c.id]=progress
  var current={"range":c.range_buff if sim.phase=="battle" else 1.0,"speed":c.speed_buff if sim.phase=="battle" else 1.0}
  var previous=buffs.get(c.id,{"range":1.0,"speed":1.0})
  for key in ["range","speed"]:
   if is_equal_approx(current[key],previous[key]): continue
   var route=[]
   if current[key]!=1.0:
    for id in sim.network(c.id):
     var provider=sim.cell_by_id(id)
     if provider.get("key","")==("radar" if key=="range" else "accelerator"):
      route=sim.bond_path(provider.id,c.id)
      break
   effects.append({"kind":"buff","id":c.id,"p":c.p,"buff":key,"gained":current[key]!=1.0,"path":route,"age":0.0,"life":0.65})
  buffs[c.id]=current
 for id in buffs.keys():
  if not active.has(id): buffs.erase(id)
 if effects.size()>48: effects=effects.slice(effects.size()-48)
func draw_pop(canvas,p,t,merge_effect):
 var tint=Color(1,0.83,0.45,1-t) if merge_effect else Color(0.64,0.92,0.9,1-t)
 var pop=sin(t*PI)
 canvas.draw_circle(p,23+pop*3,Color(tint,(1-t)*0.18))
 for i in range(6 if merge_effect else 4):
  var d=Vector2.from_angle(i*TAU/(6 if merge_effect else 4)-PI/2)
  var q=p+d*(27+pop*5)
  if merge_effect:
   canvas.draw_colored_polygon(PackedVector2Array([q+d*3,q+d.orthogonal()*2,q-d*3,q-d.orthogonal()*2]),tint)
  else:canvas.draw_arc(q,2,0,TAU,8,tint,1.5,true)
func readiness_of(sim,c):
 var cost=0.0
 match c.key:
  "generator":cost=sim.constant_of(c,"proteinAmount",8)
  "mint":cost=sim.constant_of(c,"proteinAmount",5)
  "mortar":cost=sim.constant_of(c,"consume",4)
  "tag_splitter":cost=sim.constant_of(c,"tagAmount",3)
  "accelerator":cost=sim.constant_of(c,"consume",2)
 if cost>0:
  return {"kind":"recipe","fraction":clampf(float(c.food)/cost,0,1)}
 if c.key=="seeker_factory" and sim.experimental:
  var capsid_cost=maxf(1,sim.constant_of(c,"capsid",1))
  var bullet_cost=maxf(1,sim.constant_of(c,"bullet",2))
  # Count acquired ingredients with each kind capped at its own requirement.
  # Surplus food cannot fill the missing-bullet part of the progress arc.
  var acquired=clampf(float(c.food),0,capsid_cost)+clampf(float(c.get("bullet_food",0)),0,bullet_cost)
  return {"kind":"recipe","fraction":acquired/(capsid_cost+bullet_cost)}
 var interval=sim.interval_of(c)
 if interval>0 and sim.catalog[c.key].behavior in ["shoot","sniper","heal","push","spray","drop"]:
  if c.key=="tag_sprayer" and int(c.get("tags",0))<=0:return {}
  return {"kind":"cooldown","fraction":1-clampf(c.cool/interval,0,1)}
 return {}
func draw_cell(canvas,c):
 if readiness.has(c.id):
  var state=readiness[c.id]
  var color=Color("#e4c36f") if state.kind=="recipe" else Color("#6f969c")
  canvas.draw_arc(c.p,29,PI*0.2,PI*0.8,18,Color(color,0.22),2,true)
  if state.fraction>0:
   canvas.draw_arc(c.p,29,PI*0.2,PI*(0.2+0.6*state.fraction),18,color,2,true)
 if c.key=="tag_sprayer" and c.has("tags"):
  canvas.draw_string(ThemeDB.fallback_font,c.p+Vector2(-18,-29),"EMPTY" if c.tags==0 else str(c.tags)+" tags",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#644c7d"))
 if c.key=="generator":
  for i in range(8):
   var p=c.p+Vector2(-9+(i%4)*6,11+floori(i/4.0)*5)
   canvas.draw_circle(p,1.6,Color("#f5d078") if i<c.food else Color("#567772"))
 var state=buffs.get(c.id,{})
 if state.get("range",1.0)!=1.0:
  canvas.draw_arc(c.p+Vector2(18,-20),4,PI,TAU,12,Color("#b4ebed"),1.8,true)
  canvas.draw_circle(c.p+Vector2(18,-20),1.4,Color("#2c6168"))
 if state.get("speed",1.0)!=1.0:
  for i in range(2):
   var p=c.p+Vector2(-21+i*4,-20)
   canvas.draw_polyline(PackedVector2Array([p+Vector2(-2,-3),p,p+Vector2(-2,3)]),Color("#ead792"),1.5,true)
func draw(canvas):
 waves.draw(canvas)
 for e in effects.slice(maxi(0,effects.size()-12)):
  var t=e.age/e.life
  var color=Color(0.62,0.9,0.72,1-t)
  if e.kind=="heal" or e.kind=="generator_fed":
   var origin=e.get("from",e.p)
   if origin.distance_to(e.p)>1:
    canvas.draw_line(origin,e.p,Color(color,0.18*(1-t)),1,true)
    canvas.draw_circle(origin.lerp(e.p,minf(1,t*2)),3,Color(0.99,0.83,0.43,1-t) if e.kind=="generator_fed" else color)
   if e.kind=="heal":
    canvas.draw_circle(e.p,22,Color(0.8,1,0.85,(1-t)*0.2))
    var p=e.p+Vector2(0,-23-t*8)
    canvas.draw_line(p+Vector2(-3,0),p+Vector2(3,0),color,2,true)
    canvas.draw_line(p+Vector2(0,-3),p+Vector2(0,3),color,2,true)
  elif e.kind=="generator_charged":
   canvas.draw_arc(e.p,22+t*15,0,TAU,32,Color(1,0.87,0.48,1-t),2,true)
   canvas.draw_string(ThemeDB.fallback_font,e.p+Vector2(-23,-30-t*10),"+8 charge",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.36,0.33,0.18,1-t))
  elif e.kind=="bullet_split":
   var start=e.p-e.direction*15
   for side in [-1,1]:
    var end=e.p+e.direction.rotated(side*0.35)*(20+t*12)
    canvas.draw_polyline(PackedVector2Array([start,e.p,end]),Color(0.7,0.91,1,1-t),2,true)
  elif e.kind=="attack_fired":
   var d=e.direction.normalized()
   # Short bubbles mark the observed firing direction, not a predicted hit.
   for i in range(3):
    var p=e.p+d*(7+i*6+t*10)+d.orthogonal()*sin(i*2.2)*2
    canvas.draw_arc(p,(3-i*0.6)*(1-t*0.5),0,TAU,10,Color(0.83,0.97,1,(1-t)*0.65),1.2,true)
  elif e.kind=="accelerated":
   canvas.draw_line(e.p,e.q,Color(0.97,0.82,0.46,(1-t)*0.4),1.5,true)
   canvas.draw_circle(e.p.lerp(e.q,t),3,Color(0.97,0.82,0.46,1-t))
   canvas.draw_arc(e.q,21,0,TAU*t,20,Color(0.97,0.82,0.46,1-t),2,true)
  elif e.kind=="swap":
   var normal=e.p.direction_to(e.q).orthogonal()*4
   canvas.draw_line(e.p+normal,e.q+normal,Color(0.72,0.66,0.94,(1-t)*0.6),1.5,true)
   canvas.draw_line(e.p-normal,e.q-normal,Color(0.72,0.66,0.94,(1-t)*0.6),1.5,true)
   canvas.draw_circle(e.p.lerp(e.q,t)+normal,3,Color(0.72,0.66,0.94,1-t))
   canvas.draw_circle(e.q.lerp(e.p,t)-normal,3,Color(0.72,0.66,0.94,1-t))
   canvas.draw_string(ThemeDB.fallback_font,e.p+Vector2(-15,-28),"%s > %s HP" % [e.before_a,e.after_a],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.36,0.29,0.49,1-t))
   canvas.draw_string(ThemeDB.fallback_font,e.q+Vector2(-15,-28),"%s > %s HP" % [e.before_b,e.after_b],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.36,0.29,0.49,1-t))
  elif e.kind=="buff":
   var recipient=observed_sim.cell_by_id(e.id)
   if recipient.is_empty() or not recipient.alive: continue
   e.p=recipient.p
   if e.gained: draw_pop(canvas,e.p,t,false)
   var tint=Color(0.61,0.89,0.94,1-t) if e.buff=="range" else Color(0.97,0.82,0.46,1-t)
   if e.path.size()>1: canvas.draw_polyline(PackedVector2Array(e.path),Color(tint,0.4*(1-t)),2,true)
   canvas.draw_arc(e.p,20+(t if e.gained else 1-t)*8,0,PI*1.5,28,tint,1.5,true)
  elif e.kind=="merge":
   var recipient=observed_sim.cell_by_id(e.id)
   if not recipient.is_empty() and recipient.alive: draw_pop(canvas,recipient.p,t,true)
  elif e.kind=="purchase_buff":
   var recipient=observed_sim.cell_by_id(e.id)
   if recipient.is_empty() or not recipient.alive:continue
   var provider=observed_sim.cell_by_id(e.source_id)
   var origin=provider.get("p",e["from"])
   var destination=recipient.p
   var tint=Color(0.67,0.94,0.86,1-t)
   canvas.draw_arc(origin,24+t*5,0,TAU,24,tint,1.5,true)
   canvas.draw_dashed_line(origin,destination,Color(tint,0.2*(1-t)),1,7,true)
   canvas.draw_circle(origin.lerp(destination,minf(1,t*2)),3,tint)
   draw_pop(canvas,destination,t,false)
  elif e.kind=="cell_target":
   var recipient=observed_sim.cell_by_id(e.id)
   if recipient.is_empty() or not recipient.alive:continue
   var p=recipient.p+Vector2(0,-33-t*4)
   var tint=Color(0.92,0.71,0.33,1-t)
   if e.target_id>=0:
    canvas.draw_line(p+Vector2(0,-4),p+Vector2(0,1),tint,2,true)
    canvas.draw_circle(p+Vector2(0,4),1.3,tint)
   else:
    # Loss is distinct from the delayed return transition.
    canvas.draw_arc(p,4,PI*0.15,PI*1.7,12,Color(0.48,0.68,0.73,1-t),1.5,true)
  elif e.kind=="cell_return":
   var recipient=observed_sim.cell_by_id(e.id)
   if recipient.is_empty() or not recipient.alive or not recipient.get("seeker_returning",false):continue
   var p=recipient.p+Vector2(0,-35-t*4)
   var tint=Color(0.18,0.37,0.45,1-t)
   canvas.draw_arc(p,3,-PI,PI*0.45,14,tint,1.7,true)
   canvas.draw_line(p+Vector2(0,3),p+Vector2(0,5),tint,1.7,true)
   canvas.draw_circle(p+Vector2(0,8),1.2,tint)
  elif e.kind=="interferon_created":
   var tint=Color(0.74,0.62,0.91,(1-t)*0.65)
   for i in range(3):
    var d=Vector2.from_angle(i*TAU/3-PI/2)
    var p=e.p+d*(6+t*9)
    canvas.draw_polyline(PackedVector2Array([p-d*2+d.orthogonal()*2,p,p-d*2-d.orthogonal()*2]),tint,1.3,true)
func purchase_preview(sim,key,p,reward=false):
 if sim.phase!="shop" or p==Vector2.INF or not sim.catalog.has(key):return []
 if not reward and sim.money<int(sim.shop_rules.buy_price):return []
 if sim.catalog[key].category!="B":return []
 var recipient={}
 for c in sim.cells:
  if sim.compatible(c,{"id":-1,"key":key,"rank":1}) and c.rank+1<=3:
   if recipient.is_empty() or c.p.distance_to(p)<recipient.p.distance_to(p):recipient=c
 var direct=not recipient.is_empty() and (sim.cells.size()>=sim.capacity() or recipient.p.distance_to(p)<44)
 if sim.cells.size()>=sim.capacity() and not direct:return []
 var destination=recipient.p if direct else p
 var routes=[]
 for c in sim.cells:
  if c.key=="resonant_buffer":routes.append({"from":c.p,"to":destination})
  elif c.key=="resonant_wall":routes.append({"from":destination,"to":c.p})
 return routes
func draw_purchase_preview(canvas,sim,key,p,reward=false):
 for route in purchase_preview(sim,key,p,reward):
  canvas.draw_dashed_line(route["from"],route.to,Color(0.67,0.94,0.86,0.5),1.5,6,true)
  canvas.draw_arc(route.to,27,0,TAU,24,Color(0.67,0.94,0.86,0.7),1.5,true)
