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
 var s=load("res://scripts/simulation.gd").new();s.reset(42,12)
 layer.update(s,0)
 v.age=0;v.emerging=false
 assert(layer.spawn_alpha(v)==1,"Gym setup actors remain fully visible before the simulation clock starts")
 print("PASS: seven spawn opacity/lifetime/immutability/Gym setup checks")
 quit()
