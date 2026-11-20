extends SceneTree
class Capture extends RefCounted:
 var captured
 func draw_mesh(mesh,_texture):captured=mesh
func _initialize():
 var c=Capture.new();var w=preload('res://atlas_integration/body_warp.gd').new()
 w.draw(c,null,200,0,Vector2.LEFT,0.1,1.0)
 var vertices=c.captured.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var good=vertices is PackedVector2Array and vertices.size()==49 and w.meshes.size()==1 and w.meshes[0]==c.captured
 print('PASS: hit deformation uses a nonempty Canvas2D mesh' if good else 'FAIL: invalid 2D impact mesh')
 quit(0 if good else 1)
