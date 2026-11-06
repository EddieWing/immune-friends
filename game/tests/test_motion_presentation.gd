extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/motion_presentation.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok: errors+=1
func _initialize():
 for speed in [1,5]:
  var sim=Sim.new()
  sim.reset(42,12)
  sim.phase="battle"
  sim.spawn_virus({"type":"basic","lane":0,"p":Vector2(500,0)})
  var v=sim.viruses[0]
  v.emerging=false
  var view=View.new()
  var before=var_to_bytes(sim.physics.states)
  view.update(sim)
  check(view.wakes.is_empty() and var_to_bytes(sim.physics.states)==before,"Idle observation creates no physics state")
  sim.physics.states[v.id]={"v":Vector2(40,0),"w":0.0}
  sim.elapsed+=float(speed)/60
  view.update(sim)
  check(view.wakes.size()==1 and view.wakes[0].mode=="accelerate","Actual acceleration produces wake x"+str(speed))
  sim.elapsed+=float(speed)/60
  view.update(sim)
  check(view.wakes[0].mode=="glide","Constant speed becomes glide")
  sim.physics.states[v.id].v=Vector2(10,0)
  sim.elapsed+=float(speed)/60
  view.update(sim)
  check(view.wakes[0].mode=="brake","Deceleration shows pressure in front")
  sim.physics.states[v.id].v=Vector2(-30,15)
  sim.elapsed+=float(speed)/60
  before=var_to_bytes(sim.physics.states)
  var body_before=var_to_bytes(v)
  view.update(sim)
  check(view.wakes[0].direction.is_equal_approx(Vector2(-30,15).normalized()),"Reversal follows actual velocity")
  check(var_to_bytes(sim.physics.states)==before and var_to_bytes(v)==body_before,"No collider position or velocity mutation")
  v.freeze=1
  view.update(sim)
  check(view.wakes.is_empty(),"Suspend suppresses wake even with residual velocity")
  v.freeze=0;v.alive=false
  view.update(sim)
  check(view.wakes.is_empty() and view.samples.is_empty(),"Death removes motion history")
  sim.reset(43,12)
  view.update(sim)
  check(view.wakes.is_empty(),"Reset has no previous motion")
 quit(errors)
