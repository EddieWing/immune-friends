extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate()
 scene.save_path="user://debug-isolation-%d.json" % Time.get_ticks_usec()
 scene.settings_path="user://debug-test.cfg"
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.main_menu.hide()
 var sim=scene.sim
 var money=sim.money
 scene.lab_tools.debug_arm("cell","wall")
 scene.gym_place(Vector2(200,60))
 check(sim.cells.size()==1 and sim.cells[0].key=="wall" and sim.money==money,"Debug places chosen cell in a normal run without economy cost")
 scene.lab_tools.debug_arm("source","jumper")
 var lane=sim.infection_sources.size()
 scene.gym_place(Vector2(310,75))
 check(sim.infection_sources[lane]==Vector2(310,75) and sim.wave.back().count==5,"Debug adds a positioned source with selected threat and count")
 sim.begin_battle()
 check(sim.spawn_queue.filter(func(e): return e.lane==lane).size()==5,"Preparation source participates in the next infection")
 scene.lab_tools.debug_arm("source","seeker")
 scene.gym_place(Vector2(-300,80))
 check(scene.paused and sim.spawn_queue.back().type=="seeker","Battle placement pauses and adds viruses to the live queue")
 sim.spawn_virus(sim.spawn_queue.back())
 check(sim.viruses.back().emerging and sim.viruses.back().p==Vector2(-300,80),"New threat emerges from its source using normal spawning")
 var p=sim.blood[0].p
 sim.blood[0].alive=false
 scene.debug_replenish_core()
 check(sim.blood[0].alive and sim.blood[0].p==p,"Core replenishment revives lost cells in place")
 var diagnostics=scene.view.diagnostics
 diagnostics.update(sim,0.016)
 var c=sim.cells[0]
 c.p+=Vector2(10,0)
 sim.elapsed+=0.1
 diagnostics.update(sim,0.1)
 var track=diagnostics.tracks["cell:"+str(c.id)]
 check(track.points.size()==2 and track.velocity.is_equal_approx(Vector2(100,0)),"Travel trail and movement vector reflect actual displacement")
 diagnostics.update(sim,0.1)
 check(track.velocity==Vector2(100,0),"Paused diagnostics retain the last movement vector")
 for i in range(1200):
  c.p+=Vector2(3,0)
  sim.elapsed+=0.1
  diagnostics.update(sim,0.1)
 check(track.points.size()<=512 and track.points[0]==Vector2(200,60),"Long paths stay bounded and retain the starting point")
 sim.elapsed=0
 diagnostics.update(sim,0.1)
 check(diagnostics.tracks["cell:"+str(c.id)].points.size()==1,"Restart clears trails from the previous infection")
 scene.enter_gym()
 scene.main_menu.hide()
 scene.lab_tools.debug_arm("source","basic")
 scene.gym_place(Vector2(300,0))
 scene.gym_run()
 check(scene.sim.spawn_queue.size()==5,"Gym runs deliberately added sources")
 scene.gym_reset_setup()
 check(scene.sim.wave.size()==1 and scene.sim.wave[0].count==5,"Gym reset restores source setup")
 var toggle=scene.lab_tools.debug_panel.find_child("debug_ranges",true,false)
 toggle.button_pressed=true
 check(scene.view.debug_ranges,"F3 radius toggle controls overlay in Gym")
 var ranged=scene.sim.make_cell("seeker",Vector2(210,30))
 scene.sim.cells.append(ranged)
 var markers=diagnostics.range_markers(scene.sim)
 check(markers.any(func(m): return m.p==ranged.p and m.kind=="ability" and m.r==scene.sim.range_of(ranged)),"Debug radius matches effective simulation range")
 ranged.alive=false
 check(not diagnostics.range_markers(scene.sim).any(func(m): return m.p==ranged.p),"Dead cells have no radius overlays")
 scene.view.debug_geometry=true
 scene.view.debug_paths=true
 scene.view.debug_vectors=true
 await process_frame
 scene.queue_free()
 await process_frame
 print("RESULT: debug checks, %d failures" % failures)
 quit(1 if failures else 0)
