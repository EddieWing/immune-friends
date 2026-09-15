extends RefCounted
# Read-only diagnostics; positions are sampled even when overlays are hidden.
var revision_seen=-1
var observed_sim
var phase=""
var elapsed=0.0
var round_no=-1
var tracks={}
func update(sim,delta):
 if revision_seen!=sim.presentation_revision or observed_sim!=sim or round_no!=sim.round_no or sim.elapsed<elapsed or (sim.phase=="battle" and phase!="battle"):
  tracks.clear()
 revision_seen=sim.presentation_revision
 observed_sim=sim
 round_no=sim.round_no
 var dt=sim.elapsed-elapsed if sim.phase=="battle" else delta
 phase=sim.phase
 elapsed=sim.elapsed
 for track in tracks.values(): track.active=false
 for group in [["cell",sim.cells],["core",sim.blood],["virus",sim.viruses]]:
  for item in group[1]:
   if not item.alive: continue
   var key=group[0]+":"+str(item.id)
   if not tracks.has(key):
    if tracks.size()>=512: tracks.erase(tracks.keys()[0])
    var origin=item.get("spawn_position",item.p) if group[0]=="virus" else item.p
    tracks[key]={"points":[origin],"previous":item.p,"velocity":Vector2.ZERO,"item":item,"kind":group[0]}
   var track=tracks[key]
   track.item=item
   track.active=true
   if dt>0:
    track.velocity=(item.p-track.previous)/dt
   track.previous=item.p
   if track.points.back().distance_to(item.p)>=2:
    track.points.append(item.p)
    if track.points.size()>512:
     var reduced=[]
     for i in range(0,track.points.size(),2): reduced.append(track.points[i])
     reduced.append(track.points.back())
     track.points=reduced
func draw(view):
 if view.debug_paths:
  for track in tracks.values():
   var color=Color("#ff39da") if track.kind=="virus" else Color("#78ff28")
   if track.points.size()>1:
    view.draw_polyline(PackedVector2Array(track.points),Color.BLACK,4,true)
    view.draw_polyline(PackedVector2Array(track.points),color,2,true)
   view.draw_circle(track.points[0],3,color)
 if view.debug_vectors:
  for track in tracks.values():
   if not track.get("active",false) or not track.item.alive or track.velocity.length()<0.5: continue
   var p=track.item.p
   var d=track.velocity.normalized()
   var tip=p+d*clampf(track.velocity.length()*0.35,22,100)
   view.draw_line(p,tip,Color.BLACK,5,true)
   view.draw_line(p,tip,Color("#faff00"),2.5,true)
   view.draw_colored_polygon(PackedVector2Array([tip,tip-d*9+d.orthogonal()*5,tip-d*9-d.orthogonal()*5]),Color("#faff00"))
 if not view.debug_geometry: return
 for core in view.sim.blood:
  if core.alive: circle(view,core.p,13,Color("#ed18ff"))
 for cell in view.sim.cells:
  if not cell.alive: continue
  if view.sim.catalog[cell.key].behavior=="wall":
   view.draw_set_transform(cell.p,cell.angle)
   view.draw_rect(Rect2(-43,-13,86,26),Color(1,0,0.15,0.3),true)
   view.draw_rect(Rect2(-43,-13,86,26),Color("#ff002b"),false,2.5)
   view.draw_set_transform(Vector2.ZERO)
  else: circle(view,cell.p,18,Color("#ff002b"))
 for virus in view.sim.viruses:
  if virus.alive: circle(view,virus.p,10,Color("#ed18ff"))
 for particle in view.sim.particles:
  if particle.kind=="bullet": circle(view,particle.p,particle.r,Color("#ff002b"))
func circle(view,p,r,color):
 view.draw_circle(p,r,Color(color,0.3))
 view.draw_arc(p,r,0,TAU,40,Color.BLACK,4,true)
 view.draw_arc(p,r,0,TAU,40,color,2.5,true)
