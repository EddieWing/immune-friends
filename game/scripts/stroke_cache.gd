extends RefCounted
# Arc topology is immutable. The arena shader changes radius on the GPU while
# retaining local stroke width; other canvases keep the ordinary mesh path.
var meshes: Array[ArrayMesh]=[]
var current={}
var topology={}
var cursor=0
var static_meshes={}
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
 if radius>=1.0 and canvas.has_meta("static_stroke_geometry"):
  canvas.draw_mesh(gpu_mesh(span,count,width),null,Transform2D(angle,Vector2.ONE*radius,0,p),color)
  return
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

func gpu_mesh(span: float,count: int,width: float):
 var key=Vector3(span,count,width)
 if static_meshes.has(key):return static_meshes[key]
 var data=basis(span,count)
 var vertices=PackedVector3Array();var uv=PackedVector2Array()
 var distances=[-width*0.5-1,-width*0.5,width*0.5,width*0.5+1]
 for i in range(count):
  for edge in range(4):
   vertices.append(Vector3(data.points[i].x,data.points[i].y,0))
   uv.append(Vector2(1000,1000)+data.normals[i]*distances[edge])
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv
 arrays[Mesh.ARRAY_COLOR]=data.colors;arrays[Mesh.ARRAY_INDEX]=data.indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 # The vertex shader expands the unit path. Cover the stroke at radius >= 1
 # so a membrane touching the viewport edge is never culled prematurely.
 var extent=1.0
 for normal: Vector2 in data.normals:extent=maxf(extent,1.0+normal.length()*(width*0.5+1.0))
 mesh.custom_aabb=AABB(Vector3(-extent,-extent,-1),Vector3(extent*2,extent*2,2))
 static_meshes[key]=mesh
 return mesh
