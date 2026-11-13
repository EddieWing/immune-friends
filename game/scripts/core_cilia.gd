extends RefCounted
# Thirty immutable AA hair meshes, instanced once per living Core.
# Animation uses arena time (including pause/reset), never shader TIME.
var batch=MultiMesh.new()
func _init():
 var vertices=PackedVector3Array();var uv=PackedVector2Array();var colors=PackedColorArray();var indices=PackedInt32Array()
 # Same nine quads per AA line as Godot: solid body, four sides, four corners.
 var w=0.1875;var outer=0.65625
 var quads=[
  [[w,0,1],[-w,0,1],[-w,1,1],[w,1,1]],
  [[w,0,1],[outer,0,0],[outer,1,0],[w,1,1]],
  [[-w,0,1],[-outer,0,0],[-outer,1,0],[-w,1,1]],
  [[w,0,1],[w,-1,0],[-w,-1,0],[-w,0,1]],
  [[w,1,1],[w,2,0],[-w,2,0],[-w,1,1]],
  [[w,0,1],[w,-1,0],[outer,-1,0],[outer,0,0]],
  [[-w,0,1],[-w,-1,0],[-outer,-1,0],[-outer,0,0]],
  [[w,1,1],[w,2,0],[outer,2,0],[outer,1,0]],
  [[-w,1,1],[-w,2,0],[-outer,2,0],[-outer,1,0]]]
 for i in range(30):
  for quad in quads:
   var base=vertices.size()
   for point in quad:
    vertices.append(Vector3(point[0],point[1],0));uv.append(Vector2(2000+i,0));colors.append(Color(1,1,1,point[2]))
   indices.append_array(PackedInt32Array([base,base+1,base+2,base,base+2,base+3]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh.custom_aabb=AABB(Vector3(-15,-15,-1),Vector3(30,30,2))
 batch.transform_format=MultiMesh.TRANSFORM_2D;batch.use_custom_data=true;batch.mesh=mesh
func prepare(blood,strengths):
 var alive=0
 for b in blood:
  if b.alive:alive+=1
 if alive==0:
  batch.visible_instance_count=0
  return
 if batch.instance_count<alive:batch.instance_count=alive
 batch.visible_instance_count=alive
 var index=0
 for b in blood:
  if not b.alive:continue
  batch.set_instance_transform_2d(index,Transform2D(0,b.p))
  batch.set_instance_custom_data(index,Color(b.id,strengths.get(b.id,0.0),0,0))
  index+=1
func draw(canvas,blood,strengths):
 prepare(blood,strengths)
 if batch.visible_instance_count>0:canvas.draw_multimesh(batch,null)
