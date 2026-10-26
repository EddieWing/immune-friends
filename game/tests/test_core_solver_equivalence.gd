extends SceneTree
func _initialize():
 var a=load("res://scripts/simulation.gd").new()
 var b=load("res://tests/legacy_core_solver.gd").new()
 a.reset(812,12);b.reset(812,12)
 var cost_a=0;var cost_b=0
 for tick in range(600):
  if tick==100:
   a.blood_drag=0;b.blood_drag=0;a.blood_target=Vector2(260,170);b.blood_target=a.blood_target
  if tick==200:a.blood_drag=-1;b.blood_drag=-1
  if tick==300:a.blood[3].alive=false;b.blood[3].alive=false
  var t=Time.get_ticks_usec();a.step_blood(1.0/60);cost_a+=Time.get_ticks_usec()-t
  t=Time.get_ticks_usec();b.step_blood(1.0/60);cost_b+=Time.get_ticks_usec()-t
  if a.blood!=b.blood or a.blood_velocity!=b.blood_velocity:
   push_error("Core solver diverged at tick "+str(tick));quit(1);return
 print("CORE EXACT EQUIVALENCE PASS new_us=",cost_a/600," old_us=",cost_b/600)
 quit()
