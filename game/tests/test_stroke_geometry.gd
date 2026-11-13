extends SceneTree
const Stroke=preload("res://scripts/stroke_cache.gd")
var failures=0
class CanvasProbe extends RefCounted:
 var last_mesh: Mesh
 var last_transform: Transform2D
 func draw_mesh(mesh, _texture, transform, _color):
  last_mesh=mesh
  last_transform=transform
func check(value,message):
 print(("PASS: " if value else "FAIL: ")+message)
 if not value:failures+=1
func _initialize():
 var cache=Stroke.new()
 var canvas=CanvasProbe.new()
 canvas.set_meta("static_stroke_geometry",true)
 cache.begin();cache.arc(canvas,Vector2(20,30),12,0.7,TAU,36,Color.WHITE,2)
 var first=canvas.last_mesh
 cache.begin();cache.arc(canvas,Vector2(50,60),40,0.2,TAU,36,Color.RED,2)
 check(canvas.last_mesh==first,"Radius, position, color and age reuse immutable geometry")
 check(canvas.last_transform.origin==Vector2(50,60) and is_equal_approx(canvas.last_transform.x.length(),40),"Current position and radius still update every draw")
 var arrays=first.surface_get_arrays(0)
 var data=cache.basis(TAU,36)
 var bounds=first.custom_aabb
 var covered=true
 for i in range(36):
  for distance in [-2.0,-1.0,1.0,2.0]:
   var point: Vector2=data.points[i]+data.normals[i]*distance
   covered=covered and bounds.has_point(Vector3(point.x,point.y,0))
 check(covered,"Expanded stroke is included in culling bounds at the minimum GPU radius")
 check(arrays[Mesh.ARRAY_INDEX]==data.indices and arrays[Mesh.ARRAY_COLOR]==data.colors,"Topology and antialias alpha bands are unchanged")
 cache.arc(canvas,Vector2.ZERO,12,0,TAU,36,Color.WHITE,1.5)
 check(canvas.last_mesh!=first,"Distinct line widths keep distinct immutable geometry")
 cache.arc(canvas,Vector2.ZERO,0.5,0,TAU,36,Color.WHITE,2)
 check(canvas.last_transform.x.length()==1 and canvas.last_mesh!=first,"Sub-unit radii use the ordinary path without a shader division or narrow bounds")
 var ordinary=CanvasProbe.new()
 cache.arc(ordinary,Vector2.ZERO,12,0,TAU,36,Color.WHITE,2)
 check(ordinary.last_transform.x.length()==1 and ordinary.last_mesh!=first,"Canvases without the arena shader retain their ordinary geometry")
 print("STROKE_GEOMETRY failures=",failures)
 quit(1 if failures else 0)
