extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/support_presentation.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok: errors+=1
func _initialize():
 var s=Sim.new()
 s.reset(42,12);s.phase="battle"
 var generator=s.make_cell("generator",Vector2.ZERO)
 var cannon=s.make_cell("cannon",Vector2(100,0))
 var wall=s.make_cell("wall",Vector2(200,0))
 s.cells=[generator,cannon,wall]
 var v=View.new()
 generator.food=4
 cannon.cool=s.interval_of(cannon)*0.25
 var before=var_to_bytes(s.cells)
 v.update(s,0)
 check(v.readiness[generator.id].fraction==0.5,"Generator reports consumed ingredients against actual recipe cost")
 check(is_equal_approx(v.readiness[cannon.id].fraction,0.75),"Cooldown reads actual interval and remaining timer")
 check(not v.readiness.has(wall.id),"No invented charge on passive Wall")
 check(var_to_bytes(s.cells)==before,"Progress cannot consume ingredients or advance cooldown")
 generator.food=0;cannon.cool=s.interval_of(cannon)
 v.update(s,0)
 check(v.readiness[generator.id].fraction==0 and v.readiness[cannon.id].fraction==0,"Progress resets after actual recipe and shot")
 var sprayer=s.make_cell("tag_sprayer",Vector2.ZERO)
 sprayer.tags=0
 check(v.readiness_of(s,sprayer).is_empty(),"Empty finite ammo does not imply a ready shot")
 s.phase="shop";v.update(s,0)
 check(v.readiness.is_empty(),"Preparation hides combat readiness")
 s.reset(43,12);v.update(s,0)
 check(v.readiness.is_empty(),"Restart clears stale recipe progress")
 quit(errors)
