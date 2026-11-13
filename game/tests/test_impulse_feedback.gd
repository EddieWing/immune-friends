extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/reaction_presentation.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok: errors+=1
func _initialize():
 for speed in [1,5]:
  var sim=Sim.new()
  sim.reset(42,12);sim.phase="battle"
  sim.spawn_virus({"type":"basic","lane":0,"p":Vector2(500,0)})
  var v=sim.viruses[0]
  var view=View.new()
  view.update(sim,0)
  check(view.pose("virus",v.id).offset==Vector2.ZERO,"No event means no visual recoil")
  # Impulse can be tangential, and need not point away from its source.
  sim.push_object(v,Vector2(0,-25),"virus",v.p-Vector2(50,0))
  var before=var_to_bytes(sim.physics.states)
  view.update(sim,0)
  check(view.pose("virus",v.id).offset==Vector2(0,-2),"Pose follows applied impulse rather than source position")
  check(view.bursts.back().direction==Vector2.UP,"Arrow and pose use the same impulse")
  check(is_equal_approx(view.pose("virus",v.id).squash,1.03),"Approved three percent push deformation preserved")
  check(var_to_bytes(sim.physics.states)==before,"No extra linear or angular impulse from visual layer")
  for i in range(100):sim.record("pushed",{"id":v.id,"p":v.p,"kind":"virus","direction":Vector2(0,200)})
  view.update(sim,0)
  check(view.pose("virus",v.id).offset.length()<=2 and view.bursts.size()<=48,"Repeated impulses are bounded")
  sim.elapsed+=0.5*speed
  view.update(sim,0)
  check(view.reactions.is_empty() and view.bursts.is_empty(),"Feedback recovers on simulation clock x"+str(speed))
 quit(errors)
