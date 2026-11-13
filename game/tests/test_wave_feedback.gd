extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/wave_presentation.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok:errors+=1
func _initialize():
 for speed in [1,5]:
  var s=Sim.new();s.reset(42,12);s.phase="battle"
  var v=View.new();v.update(s,0)
  s.start_blast(Vector2(2000,0),100)
  s.start_blast(Vector2(2200,0),120)
  v.update(s,0)
  check(v.fronts.size()==2 and v.ripples.size()==2,"Simultaneous actual blasts produce independent fronts")
  s.advance_blasts(float(speed)/60);s.elapsed+=float(speed)/60
  var before=var_to_bytes(s.blasts)
  v.update(s,0)
  check(v.fronts[0].radius==s.blasts[0].radius,"Solid front matches actual damage radius x"+str(speed))
  check(var_to_bytes(s.blasts)==before,"Presentation cannot change damage front hit list or timing")
  var frozen=var_to_bytes(v.ripples)
  v.update(s,1)
  check(var_to_bytes(v.ripples)==frozen and v.ripples.size()==2,"Pause freezes water without duplicating blast")
  s.advance_blasts(2);s.elapsed+=2;v.update(s,0)
  check(v.fronts.is_empty() and v.ripples.is_empty(),"Front and water residue finish")
  var healer=s.make_cell("regen",Vector2.ZERO)
  var target=s.make_cell("wall",Vector2(20,0))
  s.cells=[healer,target]
  s.heal(healer,1,healer);s.heal(target,1,healer)
  s.start_blast(Vector2(3000,0),100,0,400,-1,true)
  v.update(s,0)
  check(v.heals.size()==1 and v.fronts[0].damage==0,"One healing cast echo and distinct force-front state")
  check(v.heals[0].reach==s.range_of(healer),"Healing echo uses the actual source range")
  var hp=target.hp
  v.update(s,0)
  check(target.hp==hp and v.heals.size()==1,"Visual waves neither repeat healing nor change it")
  s.reset(43,12);v.update(s,0)
  check(v.fronts.is_empty() and v.ripples.is_empty() and v.heals.is_empty(),"Reset leaves no wave residue")
 quit(errors)
