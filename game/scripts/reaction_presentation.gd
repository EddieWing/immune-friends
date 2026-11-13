extends RefCounted
var intensity=1.0
var revision_seen=-1
var observed_sim
var round_seen=-1
var phase_seen=""
var elapsed=0.0
var cursor=0
var reactions={}
var bursts=[]
var contact_holds={}
var previous_cells={}
const CONTACT_ANGLE_LIMIT=PI/36.0
func update(sim,delta):
 var fresh=observed_sim!=sim or revision_seen!=sim.presentation_revision
 revision_seen=sim.presentation_revision
 if fresh or round_seen!=sim.round_no or cursor>sim.event_sequence or sim.elapsed<elapsed or (sim.phase=="battle" and phase_seen!="battle"):
  reactions.clear()
  bursts.clear()
  contact_holds.clear()
  previous_cells.clear()
  cursor=sim.event_sequence if fresh else cursor
  elapsed=sim.elapsed
 observed_sim=sim
 round_seen=sim.round_no
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 elapsed=sim.elapsed
 phase_seen=sim.phase
 for key in contact_holds.keys():
  contact_holds[key].age+=dt
  if contact_holds[key].age>=0.18:contact_holds.erase(key)
 for key in reactions.keys():
  reactions[key].age+=dt
  if reactions[key].age>=0.38: reactions.erase(key)
 for burst in bursts: burst.age+=dt
 bursts=bursts.filter(func(b): return b.age<0.5)
 var cell_bodies={}
 for cell in sim.cells:
  if cell.alive:cell_bodies["cell:"+str(cell.id)]=cell
 var contacts_this_frame={}
 for e in sim.events_since(cursor):
  var d=e.data
  if e.event in ["damage","virus_hit","pushed"]:
   var kind=d.get("kind","cell" if e.event=="damage" else "virus")
   var key=kind+":"+str(d.id)
   reactions[key]={"age":0.0,"push":e.event=="pushed","direction":d.get("direction",d.get("from",d.p).direction_to(d.p)).normalized()}
   var contact=(e.event=="virus_hit" and d.get("cause","")=="contact") or (e.event=="damage" and d.get("source_kind","")=="virus")
   if contact and kind=="cell" and float(d.get("amount",0))>0 and cell_bodies.has(key):
    var cell=cell_bodies[key]
    var current={"p":cell.p,"angle":cell.get("angle",0.0)}
    # A second impact releases the drawing on this frame, then holds the new pose.
    var repeated=contact_holds.has(key) or contacts_this_frame.has(key)
    var anchor=current if repeated else previous_cells.get(key,current)
    contact_holds[key]={"anchor":anchor.p,"angle":anchor.angle,"age":0.0,"offset":Vector2.ZERO,"angle_offset":0.0,"released":repeated}
    contacts_this_frame[key]=true
  if e.event in ["virus_hit","pushed","tagged","thawed","tag_ended"]:
   bursts.append({"p":d.p,"age":0.0,"kind":e.event,"direction":d.get("direction",d.get("from",d.p).direction_to(d.p)).normalized()})
 cursor=sim.event_sequence
 var alive={}
 for bodies in [sim.cells,sim.viruses]:
  for body in bodies:
   if not body.alive:continue
   var key=("virus:" if body.has("type") else "cell:")+str(body.id)
   alive[key]=true
   if contact_holds.has(key):
    var hold=contact_holds[key]
    var weight=1-smoothstep(0.025,0.10,hold.age)
    hold.offset=(hold.anchor-body.p).limit_length(2)*weight
    hold.angle_offset=clampf(angle_difference(body.get("angle",0.0),hold.angle),-CONTACT_ANGLE_LIMIT,CONTACT_ANGLE_LIMIT)*weight
    if not contacts_this_frame.has(key):hold.released=false
 for key in contact_holds.keys():
  if not alive.has(key):contact_holds.erase(key)
 previous_cells.clear()
 for key in cell_bodies:
  var cell=cell_bodies[key]
  previous_cells[key]={"p":cell.p+pose("cell",cell.id).offset,"angle":cell.get("angle",0.0)+contact_holds.get(key,{}).get("angle_offset",0.0)}
 if bursts.size()>48: bursts=bursts.slice(bursts.size()-48)
func pose(kind,id):
 var r=reactions.get(kind+":"+str(id),{})
 if r.is_empty(): return {"squash":1.0,"offset":Vector2.ZERO,"hurt":false}
 var weight=1-smoothstep(0,0.38,r.age)
 # Keep the silhouette close to its collider: real momentum carries the impact.
 var recoil=r.direction*weight*2
 var hold=contact_holds.get(kind+":"+str(id),{})
 var offset=recoil
 if not hold.is_empty():
  var hold_weight=1-smoothstep(0.025,0.10,hold.age)
  offset=Vector2.ZERO if hold.released else hold.offset+recoil*(1-hold_weight)
 return {"squash":1+weight*(0.03 if r.push else -0.05),"offset":offset.limit_length(2),"hurt":not r.push and weight>0.25}
func deform_transform(kind,id,body:Transform2D):
 var reaction=reactions.get(kind+":"+str(id),{})
 var hold=contact_holds.get(kind+":"+str(id),{})
 if not hold.is_empty():
  var held_origin=body.origin
  body.origin=Vector2.ZERO
  body=Transform2D(hold.angle_offset,Vector2.ZERO)*body
  body.origin=held_origin
 if reaction.is_empty() or reaction.direction.is_zero_approx():return body
 var squash=pose(kind,id).squash
 var axis=Transform2D(reaction.direction.angle(),Vector2.ZERO)
 # Symmetric +/- delta keeps BOTH axes within the accepted 5% / 3% limit.
 var deformation=axis*Transform2D(0,Vector2(squash,2-squash),0,Vector2.ZERO)*axis.affine_inverse()
 var origin=body.origin
 body.origin=Vector2.ZERO
 body=deformation*body
 body.origin=origin
 return body
func draw(canvas):
 for b in bursts.slice(maxi(0,bursts.size()-16)):
  var t=b.age/0.5
  var color=Color(0.76,0.9,1,1-t) if b.kind in ["thawed","tagged"] else Color(0.94,0.64,0.75,1-t)
  color.a*=intensity
  if b.kind=="pushed":
   var d=b.direction
   var p=b.p-d*(23+t*8)
   canvas.draw_polyline(PackedVector2Array([p-d*6+d.orthogonal()*5,p,p-d*6-d.orthogonal()*5]),Color(0.94,0.76,0.43,1-t),2,true)
  elif b.kind in ["thawed","tag_ended"]:
   var points=PackedVector2Array()
   for i in range(5):
    var d=Vector2.from_angle(i*TAU/5)
    points.append(b.p+d*(17+t*12));points.append(b.p+d*(20+t*15))
   canvas.draw_multiline(points,color,1.5,true)
  else:
   var points=PackedVector2Array()
   for i in range(6):
    var d=Vector2.from_angle(i*TAU/6+PI/4)
    points.append(b.p+d*(13+t*18));points.append(b.p+d*(25+t*22))
   canvas.draw_multiline(points,color,3,true)
