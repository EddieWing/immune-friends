extends RefCounted
func frame(sim, phase, safe, requested, sources=[]):
 var points=[]
 var core=[]
 for b in sim.blood:
  if b.alive: core.append(b.p)
 if phase=="warning" and not sources.is_empty(): points=[sources[0]]
 else:
  points.append_array(core)
  for c in sim.cells:
   if c.alive and (phase=="shop" or near_core(c.p,core,340)): points.append(c.p)
  if phase=="battle":
   for v in sim.viruses:
    if v.alive and near_core(v.p,core,380): points.append(v.p)
 if points.is_empty(): points=[Vector2.ZERO]
 var bounds=Rect2(points[0],Vector2.ZERO)
 for p in points: bounds=bounds.expand(p)
 bounds=bounds.grow(70)
 var fit=minf(safe.size.x/maxf(bounds.size.x,1),safe.size.y/maxf(bounds.size.y,1))
 var zoom=clampf(minf(requested,fit),0.45,1.5)
 return {"focus":bounds.get_center(),"zoom":zoom,"position":safe.get_center()-bounds.get_center()*zoom}
func near_core(p,core,radius):
 for b in core:
  if p.distance_to(b)<radius: return true
 return false
