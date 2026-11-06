extends SceneTree
func _initialize():
 var layer=load("res://scripts/virus_behavior_presentation.gd").new()
 var v={"age":0.0,"p":Vector2.ZERO,"emerging":false}
 assert(is_equal_approx(layer.spawn_alpha(v),0.25))
 v.age=0.175
 assert(layer.spawn_alpha(v)>0.25 and layer.spawn_alpha(v)<1)
 v.age=0.35
 assert(layer.spawn_alpha(v)==1)
 v.emerging=true;v.spawn_position=Vector2.ZERO;v.exit=Vector2(100,0);v.p=Vector2(50,0)
 assert(is_equal_approx(layer.spawn_alpha(v),0.625))
 var before=v.duplicate(true)
 layer.spawn_alpha(v)
 assert(v==before)
 v.p=v.exit
 assert(layer.spawn_alpha(v)==1)
 print("PASS: six spawn opacity/lifetime/immutability checks")
 quit()
