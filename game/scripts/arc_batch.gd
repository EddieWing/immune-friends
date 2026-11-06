extends RefCounted
# Fixed arc meshes share one instanced draw per span. Geometry never reaches physics.
var groups={}
func begin():
 for group in groups.values():group.used=0
func make_group(span):
 var vertices=PackedVector3Array();var colors=PackedColorArray();var indices=PackedInt32Array()
 for i in range(9):
  var d=Vector2.from_angle(-span*0.5+span*i/8)
  for band in range(4):
   var r=[0.965,0.98,1.02,1.035][band]
   vertices.append(Vector3(d.x*r,d.y*r,0))
   colors.append(Color(1,1,1,0 if band in [0,3] else 1))
 for i in range(8):
  for band in range(3):
   var a=i*4+band;var b=a+4
   indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_2D;instances.use_colors=true
 instances.mesh=mesh;instances.instance_count=256;instances.visible_instance_count=0
 return {"mesh":instances,"used":0}
func add(p,radius,angle,span,color):
 if not groups.has(span):groups[span]=make_group(span)
 var group=groups[span]
 if group.used>=group.mesh.instance_count:return
 group.mesh.set_instance_transform_2d(group.used,Transform2D(angle,Vector2.ONE*radius,0,p))
 group.mesh.set_instance_color(group.used,color)
 group.used+=1
func flush(canvas):
 for group in groups.values():
  group.mesh.visible_instance_count=group.used
  if group.used>0:canvas.draw_multimesh(group.mesh,null)
