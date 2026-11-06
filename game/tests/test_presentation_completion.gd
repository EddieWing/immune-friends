extends SceneTree
func _initialize():call_deferred("run")
func run():
 var s=load("res://scripts/simulation.gd").new();s.reset(42,12)
 var view=load("res://scripts/arena_view.gd").new()

 view.microscope_effects.update(s,0)
 assert(not view.has_transient_effects())
 view.microscope_effects.trails.append({"a":Vector2.ZERO,"b":Vector2(40,0),"virus":true,"age":0.0,"life":12.0})
 assert(not view.has_transient_effects(),"Ambient viral path must not delay the results panel")
 s.record("blood_lost",{"id":0,"p":Vector2.ZERO})
 view.microscope_effects.update(s,0)
 assert(view.has_transient_effects())
 view.microscope_effects.update(s,0.8)
 assert(not view.has_transient_effects())
 view.free()
 print("PASS: water memory does not delay results; death echoes finish")
 quit()
