extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Presentation=preload("res://scripts/virus_behavior_presentation.gd")
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
  var view=Presentation.new()
  view.update(sim,0)
  check(view.suspended.is_empty(),"Stationary body is not marked suspended")
  v.freeze=0.6
  v.tag=100.0
  var before=var_to_bytes(v)
  var physics_before=var_to_bytes(sim.physics.states)
  view.update(sim,0.1)
  check(view.suspended.has(v.id),"Suspend appears from active timer x"+str(speed))
  check(view.tagged.has(v.id),"Tag and suspend are represented separately")
  check(var_to_bytes(v)==before and var_to_bytes(sim.physics.states)==physics_before,"Presentation leaves body and physics unchanged")
  var snapshot=view.suspended.duplicate(true)
  view.update(sim,1.0)
  check(view.suspended==snapshot,"Paused simulation does not consume suspend time")
  v.freeze=1.0
  sim.elapsed+=float(speed)/60
  view.update(sim,float(speed)/60)
  check(view.suspended[v.id].remaining==1.0,"Reapplication follows extended timer")
  v.freeze=0
  view.update(sim,0)
  check(view.suspended.is_empty(),"Indicator ends on exact state removal")
  check(view.tagged.has(v.id),"Tag remains after suspend expires")
  v.tag=0
  view.update(sim,0)
  check(view.tagged.is_empty(),"Tag disappears on actual state removal")
  v.freeze=1
  v.alive=false
  view.update(sim,0)
  check(view.suspended.is_empty(),"Dead virus retains no suspended overlay")
  sim.reset(43,12)
  view.update(sim,0)
  check(view.suspended.is_empty(),"Reset clears prior scene")
 quit(errors)
