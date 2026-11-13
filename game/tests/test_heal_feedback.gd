extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/support_presentation.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok: errors+=1
func _initialize():
 for speed in [1,5]:
  var s=Sim.new()
  s.reset(42,12);s.phase="battle"
  var cell=s.make_cell("wall",Vector2(80,0))
  s.cells=[cell]
  var v=View.new()
  v.update(s,0)
  s.heal(cell,1,{"p":Vector2.ZERO})
  v.update(s,0)
  check(v.effects.size()==1 and v.effects[0].id==cell.id,"Positive healing identifies recipient")
  cell.p+=Vector2(5,8)
  var before=var_to_bytes(cell)
  v.update(s,0)
  check(v.effects.size()==1 and v.effects[0].p==cell.p,"Repeated observation follows body without duplicate burst")
  check(var_to_bytes(cell)==before,"Visual does not modify health or position")
  s.record("heal",{"id":cell.id,"p":cell.p,"amount":0})
  v.update(s,0)
  check(v.effects.size()==1,"Zero healing produces no success flash")
  var age=v.effects[0].age
  v.update(s,1)
  check(v.effects[0].age==age,"Paused battle freezes healing flash")
  cell.alive=false
  v.update(s,0)
  check(v.effects.is_empty(),"No healing flash floats over a dead recipient")
  s.reset(43,12);v.update(s,0)
  check(v.effects.is_empty(),"Reset clears healing x"+str(speed))
 quit(errors)
