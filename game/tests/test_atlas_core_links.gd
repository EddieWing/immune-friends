extends SceneTree
func _initialize():
 var s=preload('res://scripts/simulation.gd').new();s.reset(42,12)
 var p=preload('res://atlas_integration/presentation.gd').new()
 var previous={};var worst=0.0;var flips=0
 for frame in 600:
  p.update(s,1.0/60)
  for id in p.connections.links:
   var l=p.connections.links[id]
   if previous.has(id):
    worst=maxf(worst,maxf(l.a.position.distance_to(previous[id][0]),l.b.position.distance_to(previous[id][2])))
    if (l.b.position-l.a.position).dot(previous[id][1])<0:flips+=1
   previous[id]=[l.a.position,l.b.position-l.a.position,l.b.position]
 print('CORE_ENDPOINT maximum jump=',worst,' direction flips=',flips,' links=',previous.size())
 quit(0 if worst<0.2 else 1)

