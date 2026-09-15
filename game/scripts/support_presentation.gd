extends RefCounted
var observed_sim
var elapsed=0.0
var cursor=0
var effects=[]
var buffs={}
func update(sim,delta):
 if observed_sim!=sim or cursor>sim.events.size():
  effects.clear()
  buffs.clear()
  cursor=sim.events.size()
  elapsed=sim.elapsed
 observed_sim=sim
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 if sim.elapsed<elapsed:
  effects.clear()
  buffs.clear()
 elapsed=sim.elapsed
 for effect in effects: effect.age+=dt
 effects=effects.filter(func(e): return e.age<e.life)
 for event in sim.events.slice(cursor):
  if event.event in ["heal","generator_fed","generator_charged","swap","bullet_split"] and event.data.has("p"):
   var e=event.data.duplicate()
   e.kind=event.event
   e.age=0.0
   e.life=1.1 if e.kind=="swap" else 0.65
   effects.append(e)
 cursor=sim.events.size()
 var active={}
 for c in sim.cells:
  if not c.alive: continue
  active[c.id]=true
  var current={"range":c.range_buff if sim.phase=="battle" else 1.0,"speed":c.speed_buff if sim.phase=="battle" else 1.0}
  var previous=buffs.get(c.id,{"range":1.0,"speed":1.0})
  for key in ["range","speed"]:
   if is_equal_approx(current[key],previous[key]): continue
   var route=[]
   if current[key]!=1.0:
    for id in sim.network(c.id):
     var provider=sim.cell_by_id(id)
     if provider.key==("radar" if key=="range" else "accelerator"):
      route=sim.bond_path(provider.id,c.id)
      break
   effects.append({"kind":"buff","p":c.p,"buff":key,"gained":current[key]!=1.0,"path":route,"age":0.0,"life":0.65})
  buffs[c.id]=current
 for id in buffs.keys():
  if not active.has(id): buffs.erase(id)
 if effects.size()>48: effects=effects.slice(effects.size()-48)
func draw_cell(canvas,c):
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
 for e in effects.slice(maxi(0,effects.size()-12)):
  var t=e.age/e.life
  var color=Color(0.62,0.9,0.72,1-t)
  if e.kind=="heal" or e.kind=="generator_fed":
   var origin=e.get("from",e.p)
   if origin.distance_to(e.p)>1:
    canvas.draw_line(origin,e.p,Color(color,0.18*(1-t)),1,true)
    canvas.draw_circle(origin.lerp(e.p,minf(1,t*2)),3,Color(0.99,0.83,0.43,1-t) if e.kind=="generator_fed" else color)
   if e.kind=="heal":
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
  elif e.kind=="swap":
   var normal=e.p.direction_to(e.q).orthogonal()*4
   canvas.draw_line(e.p+normal,e.q+normal,Color(0.72,0.66,0.94,(1-t)*0.6),1.5,true)
   canvas.draw_line(e.p-normal,e.q-normal,Color(0.72,0.66,0.94,(1-t)*0.6),1.5,true)
   canvas.draw_circle(e.p.lerp(e.q,t)+normal,3,Color(0.72,0.66,0.94,1-t))
   canvas.draw_circle(e.q.lerp(e.p,t)-normal,3,Color(0.72,0.66,0.94,1-t))
   canvas.draw_string(ThemeDB.fallback_font,e.p+Vector2(-15,-28),"%s > %s HP" % [e.before_a,e.after_a],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.36,0.29,0.49,1-t))
   canvas.draw_string(ThemeDB.fallback_font,e.q+Vector2(-15,-28),"%s > %s HP" % [e.before_b,e.after_b],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.36,0.29,0.49,1-t))
  elif e.kind=="buff":
   var tint=Color(0.61,0.89,0.94,1-t) if e.buff=="range" else Color(0.97,0.82,0.46,1-t)
   if e.path.size()>1: canvas.draw_polyline(PackedVector2Array(e.path),Color(tint,0.4*(1-t)),2,true)
   canvas.draw_arc(e.p,20+(t if e.gained else 1-t)*8,0,PI*1.5,28,tint,1.5,true)
