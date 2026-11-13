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
 s.experimental=true;s.phase="battle"
 var factory=s.make_cell("seeker_factory",Vector2.ZERO)
 s.cells=[factory]
 for sample in [[0,0,0.0],[1,0,1.0/3],[0,1,1.0/3],[0,2,2.0/3],[1,1,2.0/3],[1,2,1.0],[9,0,1.0/3],[0,9,2.0/3]]:
  factory.food=sample[0];factory.bullet_food=sample[1]
  var saved=var_to_bytes(s.cells);var rng_state=s.rng.state;var sequence=s.event_sequence
  v.update(s,0)
  check(is_equal_approx(v.readiness[factory.id].fraction,sample[2]),"Factory progress counts capped ingredients: %s food / %s bullets"%[sample[0],sample[1]])
  check(var_to_bytes(s.cells)==saved and s.rng.state==rng_state and s.event_sequence==sequence and s.pending_cells.is_empty(),"Showing partial or complete progress never produces a cell")
 factory.food=1;factory.bullet_food=1
 s.proteins.consumed(s,factory)
 check(s.pending_cells.is_empty() and factory.food==1 and factory.bullet_food==1,"Two-thirds progress cannot complete a recipe with a missing bullet")
 factory.bullet_food=2
 s.proteins.consumed(s,factory);v.update(s,0)
 check(s.pending_cells.size()==1 and s.pending_cells[0].key=="seeker" and factory.food==0 and factory.bullet_food==0 and v.readiness[factory.id].fraction==0,"Last required bullet produces one Seeker and resets the indicator")
 factory.alive=false;v.update(s,0)
 check(not v.readiness.has(factory.id),"A dead factory cannot leave a stale recipe arc")
 factory.alive=true
 for rank_value in [1,3]:
  factory.rank=rank_value
  s.catalog.seeker_factory.constants={"capsid":2,"bullet":3}
  for sample in [[2,0,0.4],[0,3,0.6],[1,1,0.4],[2,3,1.0],[8,1,0.6]]:
   factory.food=sample[0];factory.bullet_food=sample[1]
   check(is_equal_approx(v.readiness_of(s,factory).fraction,sample[2]),"Weighted progress uses actual edited recipe costs, rank %s"%rank_value)
 s.experimental=false
 check(v.readiness_of(s,factory).is_empty(),"Disabled experimental factory does not display active recipe progress")
 quit(errors)
