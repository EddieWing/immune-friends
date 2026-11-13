extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/microscope_effects.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok: errors+=1
func _initialize():
 for speed in [1,5]:
  var sim=Sim.new()
  sim.reset(42,12);sim.phase="battle"
  var wall=sim.make_cell("wall",Vector2(60,0))
  wall.angle=PI/2
  sim.cells.append(wall)
  var view=View.new()
  view.update(sim,0)
  for kind in ["blood_lost","cell_rest","virus_defeated"]:
   sim.record(kind,{"id":wall.id,"p":wall.p})
  view.update(sim,0)
  check(view.bursts.size()==3,"Core immune and virus deaths have separate identities")
  var core=view.death_particles("blood_lost")
  var immune=view.death_particles("cell_rest")
  var virus=view.death_particles("virus_defeated")
  check(core.count>immune.count and immune.count>virus.count and core.spread>immune.spread,"Core loss has priority over lesser death particles")
  check(core.color!=immune.color and immune.color!=virus.color,"Particle families use distinct own colors")
  check(view.bursts[1].wall and view.bursts[1].angle==PI/2,"Wall echo retains shape and physical orientation")
  sim.record("cell_rest",{"id":wall.id,"p":wall.p})
  view.update(sim,0)
  check(view.bursts.size()==3,"Duplicate death does not replay visual")
  var before=var_to_bytes(sim.cells)
  var particles=var_to_bytes(sim.particles)
  var frozen=var_to_bytes(view.bursts)
  view.update(sim,0.5)
  check(var_to_bytes(view.bursts)==frozen,"Pause retains death phase")
  check(var_to_bytes(sim.cells)==before and var_to_bytes(sim.particles)==particles,"Death presentation has no gameplay particles or damage")
  sim.phase="recap"
  view.update(sim,0.75)
  check(view.bursts.is_empty(),"Echoes finish during aftermath even after combat clock stops")
  sim.reset(42,12);view.update(sim,0)
  check(view.deaths_seen.is_empty() and view.bursts.is_empty(),"Reset clears death identities x"+str(speed))
 quit(errors)
