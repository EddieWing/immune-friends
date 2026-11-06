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
  sim.reset(42,12);sim.phase="battle"
  sim.spawn_virus({"type":"wave","lane":0,"p":Vector2(500,0)})
  var v=sim.viruses[0]
  v.emerging=false;v.wave_direction=Vector2.RIGHT
  var view=View.new()
  for side in [-1,1]:
   sim.physics.states[v.id]={"v":Vector2(20,side*50),"w":0.0}
   # Deliberately contradict phase, to test physical drift rather than intent.
   v.wave_progress=0.4 if side==-1 else -0.8
   sim.elapsed+=float(speed)/60
   var before=var_to_bytes(v)
   var physical=var_to_bytes(sim.physics.states)
   view.update(sim)
   check(view.wakes[0].wave_side==Vector2(0,side),"Wave side follows physical drift x"+str(speed))
   check(var_to_bytes(v)==before and var_to_bytes(sim.physics.states)==physical,"Wave visual does not alter drive or motion")
  sim.physics.states[v.id].v=Vector2(20,0)
  view.update(sim)
  check(view.wakes[0].wave_strength==0,"No side cue at lateral zero crossing")
  v.freeze=1
  view.update(sim)
  check(view.wakes.is_empty(),"No active swim cue during suspend")
 quit(errors)
