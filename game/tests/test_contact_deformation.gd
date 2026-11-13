extends SceneTree
func _initialize():
 var r=load("res://scripts/reaction_presentation.gd").new()
 for push in [false,true]:
  for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2(1,1).normalized()]:
   r.reactions["cell:1"]={"age":0.0,"push":push,"direction":direction}
   for angle in [0.0,PI/2,0.7]:
    var body=Transform2D(angle,Vector2(100,200))
    var deformed=r.deform_transform("cell",1,body)
    var relative=deformed*body.affine_inverse()
    var delta=0.03 if push else -0.05
    assert(is_equal_approx(relative.basis_xform(direction).length(),1+delta))
    assert(is_equal_approx(relative.basis_xform(direction.orthogonal()).length(),1-delta))
    assert(deformed.origin==body.origin)
 r.reactions.clear()
 assert(r.deform_transform("virus",1,Transform2D.IDENTITY)==Transform2D.IDENTITY)
 print("PASS: 18 rotated directional contacts, exact 5%/3% on both axes, stable origin")
 quit()
