extends RefCounted
# Arc topology and unit normals are immutable; only radius-dependent vertices
# change per frame. Same-age effects share one GPU mesh without dropping draws.
var meshes: Array[ArrayMesh]=[]
var current={}
var topology={}
var cursor=0
func begin():
 current.clear();cursor=0
func basis(span: float,count: int) -> Dictionary:
 var key=Vector2(span,count)
 if topology.has(key):return topology[key]
 var points=PackedVector2Array();var normals=PackedVector2Array()
 var colors=PackedColorArray();var indices=PackedInt32Array()
 for i in range(count):points.append(Vector2.from_angle(span*i/(count-1)))
 for i in range(count):
  var direction: Vector2
  var stretch=1.0
  if i==0:direction=(points[1]-points[0]).normalized()
  elif i==count-1:direction=(points[i]-points[i-1]).normalized()
  else:
   var before=(points[i]-points[i-1]).normalized()
   var after=(points[i+1]-points[i]).normalized()
   direction=(before+after).normalized()
   stretch=1.0/maxf(0.001,direction.dot(before))
  normals.append(direction.orthogonal()*stretch)
  colors.append_array(PackedColorArray([Color(1,1,1,0),Color.WHITE,Color.WHITE,Color(1,1,1,0)]))
 for i in range(count-1):
  for band in range(3):
   var a=i*4+band;var b=a+4
   indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
 var data={"points":points,"normals":normals,"colors":colors,"indices":indices}
 topology[key]=data
 return data
func arc(canvas,p: Vector2,radius: float,angle: float,span: float,count: int,color: Color,width: float):
 var key=Vector4(radius,span,count,width)
 if not current.has(key):
  if cursor>=meshes.size():meshes.append(ArrayMesh.new())
  var mesh: ArrayMesh=meshes[cursor];cursor+=1
  var data=basis(span,count)
  var points: PackedVector2Array=data.points;var normals: PackedVector2Array=data.normals
  var vertices=PackedVector3Array();vertices.resize(count*4)
  var distances=PackedFloat32Array([-width*0.5-1,-width*0.5,width*0.5,width*0.5+1])
  for i in range(count):
   var center=points[i]*radius
   for edge in range(4):
    var q=center+normals[i]*distances[edge]
    vertices[i*4+edge]=Vector3(q.x,q.y,0)
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=data.colors;arrays[Mesh.ARRAY_INDEX]=data.indices
  mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  current[key]=mesh
 canvas.draw_mesh(current[key],null,Transform2D(angle,p),color)
