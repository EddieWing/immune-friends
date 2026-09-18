extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
 var sim=load("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 var wall_key=""
 for key in sim.catalog:
  if sim.catalog[key].behavior=="wall": wall_key=key; break
 var origin=sim.infection_sources[0]
 sim.cells=[{"key":wall_key,"p":origin,"angle":PI/4,"alive":true}]
 check(not sim.source_position_clear(origin+Vector2(30,30)),"rotated wall blocks source footprint")
 var state=sim.rng.state
 sim.ensure_infection_sources_clear()
 check(sim.infection_sources[0]!=origin and sim.source_position_clear(sim.infection_sources[0]),"occupied source relocates to free space")
 check(state==sim.rng.state,"placement preserves gameplay RNG")
 var positions=sim.infection_sources.duplicate()
 sim.ensure_infection_sources_clear()
 check(positions==sim.infection_sources,"free sources stay stable")
 sim.make_wave()
 check(positions==sim.infection_sources,"same layout and seed produce same sources")
 sim.blood[0].p=sim.infection_sources[0]
 sim.ensure_infection_sources_clear()
 check(sim.source_position_clear(sim.infection_sources[0]),"Core occupancy is respected")
 sim.cells.clear()
 for x in range(-800,801,70):
  for y in range(-800,801,70):
   sim.cells.append({"key":wall_key,"p":Vector2(x,y),"angle":PI/4,"alive":true})
 sim.make_wave()
 var all_clear=true
 for p in sim.infection_sources: all_clear=all_clear and sim.source_position_clear(p)
 check(all_clear,"crowded field has bounded safe outward fallback")
 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://source-placement.cfg"
 scene.save_path="user://source-placement.json"
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.sim.reset(42,12)
 var forecast=load("res://scripts/simulation.gd").new()
 forecast.reset(42,12)
 forecast.round_no=2
 forecast.make_wave()
 var cell=scene.sim.make_cell(wall_key,forecast.infection_sources[0])
 cell.start=forecast.infection_sources[0]
 cell.p=Vector2.ZERO
 cell.alive=false
 scene.sim.cells.append(cell)
 scene.sim.phase="recap"
 scene.show_recap()
 var preview=scene.preview_sources.duplicate()
 scene.sim.next_round()
 check(preview==scene.sim.infection_sources,"forecast matches restored next-round layout including lost cells")
 check(scene.sim.source_position_clear(preview[0]),"forecast avoids restored wall")
 scene.sim.cells[0].p=preview[0]
 scene.changed()
 check(scene.sim.source_position_clear(scene.sim.infection_sources[0]),"preparation placement revalidates sources")
 quit(1 if failures else 0)
