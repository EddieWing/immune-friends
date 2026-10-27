extends RefCounted

const RELEASE_LOOKAHEAD = 0.65
const SOURCE_RADIUS = 68.0

# Read-only framing: immune cells and visual effects do not move the camera.
func interest(sim):
 var objects=[]
 for virus in sim.viruses:
  if virus.alive: objects.append({"p":virus.p,"radius":10.0})
 var seen={}
 for index in range(sim.spawn_queue.size()):
  if maxf(0.0,sim.spawn_timer)+index*sim.SPAWN_INTERVAL>RELEASE_LOOKAHEAD: break
  var lane=int(sim.spawn_queue[index].lane)
  if lane>=0 and lane<sim.infection_sources.size() and not seen.has(lane):
   seen[lane]=true
   objects.append({"p":sim.infection_sources[lane],"radius":SOURCE_RADIUS})
 if objects.is_empty(): return {}
 for core in sim.blood:
  if core.alive: objects.append({"p":core.p,"radius":13.0})
 var bounds=Rect2(objects[0].p,Vector2.ZERO)
 for object in objects:
  bounds=bounds.expand(object.p-Vector2.ONE*object.radius)
  bounds=bounds.expand(object.p+Vector2.ONE*object.radius)
 return {"focus":bounds.get_center(),"radius":maxf(bounds.size.x,bounds.size.y)*0.5}

func frame(sim,phase,safe,requested,sources=[]):
 var region={"focus":sources[0],"radius":SOURCE_RADIUS} if phase=="warning" and not sources.is_empty() else interest(sim)
 if region.is_empty(): return {}
 region.zoom=requested
 region.position=safe.get_center()-region.focus*requested
 return region

func follow_position(position,scale,safe,region,delta):
 if region.is_empty(): return position
 var center=(safe.get_center()-position)/scale
 var distance=center.distance_to(region.focus)
 var view_radius=minf(safe.size.x,safe.size.y)*0.5/scale
 # A small screen-space deadband prevents edge chatter, including oversized regions.
 if distance*scale<=8.0 or distance+region.radius<=view_radius+2.0/scale: return position
 var target=safe.get_center()-region.focus*scale
 return position.lerp(target,1.0-exp(-delta*3.0))

# Forecast is a composed overview, not infection tracking. Unused source slots
# must not influence it; make_wave reserves positions beyond the active wave.
func forecast_frame(sim,wave,sources,safe,requested):
 var points=[]
 for core in sim.blood:
  if core.alive: points.append(core.p)
 for cell in sim.cells:
  if cell.alive: points.append(cell.p)
 var lanes={}
 for entry in wave:
  var lane=int(entry.lane)
  if entry.count>0 and lane>=0 and lane<sources.size() and not lanes.has(lane):
   lanes[lane]=true
   points.append(sources[lane])
 if points.is_empty(): return {}
 var bounds=Rect2(points[0],Vector2.ZERO)
 for point in points: bounds=bounds.expand(point)
 bounds=bounds.grow(100.0)
 var zoom=minf(requested,minf(safe.size.x/bounds.size.x,safe.size.y/bounds.size.y))
 return {"focus":bounds.get_center(),"zoom":maxf(0.1,zoom),"bounds":bounds}
