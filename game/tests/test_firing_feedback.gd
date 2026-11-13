extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok: errors+=1
func _initialize():
 for speed in [1,5]:
  var s=Sim.new()
  s.reset(42,12);s.phase="battle"
  var a=preload("res://scripts/attack_presentation.gd").new()
  var v=preload("res://scripts/support_presentation.gd").new()
  a.update(s,0);v.update(s,0)
  for key in ["cannon","sniper","impact_wall"]:
   var c=s.make_cell(key,Vector2.ZERO)
   s.cells.append(c)
   s.shoot(c,Vector2(2,-1))
   var before=var_to_bytes(s.particles)
   a.update(s,0);v.update(s,0)
   check(a.poses[c.id].kick==1 and a.poses[c.id].direction.is_equal_approx(Vector2(2,-1).normalized()),"Real firing gives directed recoil: "+key)
   check(v.effects.back().kind=="attack_fired" and v.effects.back().direction.is_equal_approx(a.poses[c.id].direction),"Bubbles match firing direction")
   check(before==var_to_bytes(s.particles),"Feedback does not move or create gameplay bullets")
  var count=v.effects.size()
  s.record("attack_fired",{"id":999,"p":Vector2.ZERO,"direction":Vector2.ZERO,"key":"pusher"})
  a.update(s,0);v.update(s,0)
  check(v.effects.size()==count,"Radial action does not invent a shot direction")
  s.elapsed+=0.7*speed
  a.update(s,0);v.update(s,0)
  check(a.recoil.is_empty() and v.effects.is_empty(),"Firing feedback expires x"+str(speed))
 quit(errors)
