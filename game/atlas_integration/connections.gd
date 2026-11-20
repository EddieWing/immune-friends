extends RefCounted
# Visual endpoints and transfers only. Never writes to simulation links or bodies.
var links={}
var transfers=[]
var renderer
var states={}
func _init(painter):renderer=painter
func key(body):return ('virus:' if body.has('type') else 'cell:' if body.has('key') else 'core:')+str(body.id)
func width(sim,body):
 var result=34.0
 if body.has('type'):result=sim.physics.radius(body)*3.0
 elif body.has('key'):result=sim.physics.extent(sim,body,Vector2.RIGHT.rotated(body.get('angle',0.0)))*(2.2 if sim.catalog[body.key].behavior=='wall' else 2.5)
 return result*renderer.resting_scale(states[key(body)]) if states.has(key(body)) else result
func rig_id(body):return 'virus_'+body.type if body.has('type') else body.get('key','core')
func endpoint(sim,body,other,previous,delta):
 var spec=renderer.data.characters[rig_id(body)]
 var points=spec.body_bounds
 var angle=renderer.visual_angle(states[key(body)],body.get('angle',0.0)) if states.has(key(body)) else body.get('angle',0.0)
 var direction=(other.p-body.p).rotated(-angle).normalized()
 var origin=Vector2(spec.face[0],spec.face[1])
 var best=INF;var desired=0.0
 for i in points.size():
  var a=Vector2(points[i][0],points[i][1]);var b=Vector2(points[(i+1)%points.size()][0],points[(i+1)%points.size()][1])
  var edge=b-a;var den=direction.cross(edge)
  if absf(den)<0.00001:continue
  var t=(a-origin).cross(edge)/den;var u=(a-origin).cross(direction)/den
  if t>=0 and u>=0 and u<=1 and t<best:best=t;desired=i+u
 var param=desired
 if previous>=0:
  var distance=fposmod(desired-previous+points.size()*0.5,points.size())-points.size()*0.5
  param=fposmod(previous+clampf(distance,-delta*points.size(),delta*points.size()),points.size())
 var index=int(param)%points.size();var fraction=param-index
 var local=Vector2(points[index][0],points[index][1]).lerp(Vector2(points[(index+1)%points.size()][0],points[(index+1)%points.size()][1]),fraction)
 var position=body.p+(local*width(sim,body)/spec.width).rotated(angle)
 return {'parameter':param,'position':position,'color':Color(spec.get('color','#dcb880')),'edge':Color(spec.get('edge','#90704d'))}
func add_pair(sim,a,b,kind,delta,active):
 if a.is_empty() or b.is_empty() or not a.alive or not b.alive:return
 var ka=key(a);var kb=key(b);var id=ka+'|'+kb
 active[id]=true
 var link=links.get(id,{'age':0.0,'a':{'parameter':-1},'b':{'parameter':-1}})
 link.age+=delta;link.ka=ka;link.kb=kb;link.kind=kind;link.release=0.0
 link.a=endpoint(sim,a,b,link.a.parameter,delta);link.b=endpoint(sim,b,a,link.b.parameter,delta)
 links[id]=link
func update(sim,delta):
 var active={}
 for link in sim.links:
  var a={};var b={}
  if link.get('swarm',false):
   for body in sim.viruses:
    if body.id==link.a:a=body
    if body.id==link.b:b=body
  else:a=sim.endpoint_by_id(link.a);b=sim.endpoint_by_id(link.b)
  add_pair(sim,a,b,'virus' if link.get('swarm',false) else 'immune',delta,active)
 for link in sim.blood_links:
  if link.a<sim.blood.size() and link.b<sim.blood.size():add_pair(sim,sim.blood[link.a],sim.blood[link.b],'core',delta,active)
 for id in links.keys():
  if not active.has(id):
   links[id].release+=delta
   if links[id].release>0.3:links.erase(id)
 for transfer in transfers:transfer.age+=delta
 transfers=transfers.filter(func(t):return t.age<0.65*t.path.size())
func heal(source,target):
 if source==target:return
 var queue=[source];var visited={source:[]}
 while not queue.is_empty():
  var at=queue.pop_front()
  if at==target:
   if not visited[at].is_empty():transfers.append({'path':visited[at],'age':0.0})
   return
  for id in links:
   var link=links[id]
   if link.release>0 or link.kind=='virus':continue
   var next=link.kb if link.ka==at else link.ka if link.kb==at else ''
   if next=='' or visited.has(next):continue
   var path=visited[at].duplicate();path.append({'id':id,'reverse':link.kb==at});visited[next]=path;queue.append(next)
func draw(canvas,kind):
 for id in links:
  var link=links[id]
  if link.kind!=kind:continue
  var a=link.a.position;var b=link.b.position;var direction=(b-a).normalized()
  var reach=smoothstep(0.12,0.55,link.age)*(1-smoothstep(0.0,0.3,link.release))
  var mid=a.lerp(b,0.5)
  for side in 2:
   var data=link.a if side==0 else link.b;var base=a if side==0 else b
   var tip=base.lerp(mid,reach);var dir=direction if side==0 else -direction
   var thickness=clampf(a.distance_to(b)*0.06,1.2,3.0)
   var bud=base+dir*thickness*0.4
   canvas.draw_circle(bud,thickness*1.35,data.edge)
   canvas.draw_circle(bud,thickness*1.1,data.color)
   canvas.draw_line(base,tip,data.edge,thickness+1.0,true)
   canvas.draw_line(base,tip,data.color,thickness,true)
   for finger in [-1,0,1]:
    var hand=tip+dir*thickness*1.3+dir.orthogonal()*finger*thickness*0.8*(1-reach*0.5)
    canvas.draw_line(tip,hand,data.edge,thickness*0.6+0.5,true)
    canvas.draw_line(tip,hand,data.color,thickness*0.6,true)
 for transfer in transfers:
  var segment=mini(int(transfer.age/0.65),transfer.path.size()-1);var part=transfer.path[segment]
  if not links.has(part.id) or links[part.id].kind!=kind:continue
  var link=links[part.id];var u=fmod(transfer.age/0.65,1.0)
  if part.reverse:u=1-u
  var position=link.a.position.lerp(link.b.position,u)
  var side=link.a if u<0.5 else link.b
  canvas.draw_circle(position,3.2,side.edge);canvas.draw_circle(position,2.7,side.color)
  canvas.draw_circle(position,1.4,Color('#d9f0bf'))
