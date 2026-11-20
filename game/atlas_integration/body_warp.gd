extends RefCounted
# Presentation-only texture mesh. The hit direction is in local body coordinates.
# A single draw call replaces the sprite only while a directional impact is active.
func draw(canvas, texture, extent, frame, direction, age, alpha):
 var vertices=PackedVector2Array()
 var uv=PackedVector2Array()
 var indices=PackedInt32Array()
 var colors=PackedColorArray()
 var n=6
 var impulse=exp(-age*7.0)*cos(age*22.0)
 for y in range(n+1):
  for x in range(n+1):
   var unit=Vector2(x/float(n),y/float(n))
   var p=(unit-Vector2.ONE*0.5)*extent
   var along=p.dot(direction)/extent
   var across=p.dot(direction.orthogonal())/extent
   var falloff=exp(-pow((along-0.30)/0.22,2)-pow(across/0.28,2))
   p-=direction*extent*0.065*falloff*impulse
   vertices.append(p)
   uv.append((Vector2(frame%8,int(frame/8))+unit)/Vector2(8,9))
   colors.append(Color(1,1,1,alpha))
 for y in n:
  for x in n:
   var i=y*(n+1)+x
   indices.append_array(PackedInt32Array([i,i+1,i+n+2,i,i+n+2,i+n+1]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv
 arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_COLOR]=colors
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 canvas.draw_mesh(mesh,texture)
