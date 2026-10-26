extends SceneTree
var failures=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok: failures+=1
func _initialize():call_deferred("run")
func snapshot(s):
 return var_to_bytes([s.phase,s.elapsed,s.cells,s.blood,s.blood_velocity,s.viruses,s.particles,s.links,s.spawn_queue,s.spawn_timer,s.rng.state,s.round_losses,s.battle_income,s.physics.states,s.events])
func setup(g):
 g.sim=load("res://scripts/simulation.gd").new()
 g.sim.reset(812,12)
 g.sim.cells.append(g.sim.make_cell("turret",Vector2(90,0)))
 g.sim.cells.append(g.sim.make_cell("wall",Vector2(140,0)))
 g.sim.rebuild_links()
 g.sim.begin_battle()
 g.launch_remaining=0
 g.paused=false
func run():
 var g=load("res://main.tscn").instantiate()
 g.settings_path="user://fixed-step-test.cfg"
 g.save_path="user://fixed-step-test.json"
 root.add_child(g)
 await process_frame
 g.set_process(false)
 g.main_menu.hide()
 g.modal.hide()
 var reference=PackedByteArray()
 for fps in [5,30,144]:
  for speed in [1,2,5]:
   setup(g)
   g.set_playback_speed(speed)
   for frame in range(roundi(10.0*fps/speed)):g.advance_simulation(1.0/fps)
   var state=snapshot(g.sim)
   if reference.is_empty():reference=state
   check(state==reference,"Identical complete state at 10s: %d FPS x%d"%[fps,speed])
 var outcomes=[]
 for fps in [5,30,144]:
  setup(g)
  g.set_playback_speed(5 if fps==5 else 2 if fps==30 else 1)
  for frame in range(fps*190):
   g.advance_simulation(1.0/fps)
   if g.sim.phase!="battle":break
  outcomes.append(snapshot(g.sim))
 check(outcomes[0]==outcomes[1] and outcomes[1]==outcomes[2],"Same full battle outcome across FPS and playback speeds")
 setup(g)
 g.set_playback_speed(1)
 g.advance_simulation(2.0)
 check(is_equal_approx(g.sim.elapsed,1.0) and is_equal_approx(g.clock_accum,1.0),"Slow frame has bounded work and retains time debt")
 g.paused=true
 var before=snapshot(g.sim)
 g.advance_simulation(4.0)
 check(snapshot(g.sim)==before and is_equal_approx(g.clock_accum,1.0),"Pause freezes state and catch-up debt")
 g.paused=false
 g.advance_simulation(0)
 check(is_equal_approx(g.sim.elapsed,2.0) and g.clock_accum<0.000001,"Catch-up processes retained time without dropping ticks")
 setup(g)
 g.set_playback_speed(5)
 g.advance_simulation(0.2)
 var expected=snapshot(g.sim)
 setup(g)
 g.set_playback_speed(5)
 g.advance_simulation(0.2,1)
 check(is_equal_approx(g.sim.elapsed,1.0/60) and g.clock_accum>0.98,"Tiny frame budget yields after a whole tick and retains debt")
 var frames=0
 while g.clock_accum>0.000000001 and frames<100:
  g.advance_simulation(0,1)
  frames+=1
 check(snapshot(g.sim)==expected,"Budgeted catch-up preserves exact battle state without dropping ticks")
 g.set_playback_speed(1)
 setup(g)
 g.launch_remaining=0.9
 g.paused=true
 g.advance_simulation(1)
 check(g.launch_remaining==0.9 and g.sim.elapsed==0,"Pause freezes launch countdown")
 g.paused=false
 g.advance_simulation(1)
 check(is_equal_approx(g.sim.elapsed,0.1),"Launch preserves remainder of crossing frame")
 var prep=[]
 for fps in [5,30,144]:
  g.sim=load("res://scripts/simulation.gd").new()
  g.sim.reset(812,12)
  for b in g.sim.blood:b.p+=Vector2(180,70)
  g.set_playback_speed(5)
  for frame in range(fps*2):g.advance_simulation(1.0/fps)
  prep.append(snapshot(g.sim))
 check(prep[0]==prep[1] and prep[1]==prep[2],"Preparation drift uses fixed steps independent of FPS and battle speed")
 g.advance_simulation(0.005)
 g.sim.begin_battle()
 g.set_playback_speed(1)
 g.advance_simulation(0.012)
 check(g.sim.elapsed==0,"Preparation remainder does not leak into battle")
 g.sim.reset(812,12)
 g.sim.begin_battle()
 g.advance_simulation(0.006)
 check(g.sim.elapsed==0,"Reset clears previous run remainder even in same phase")
 g.queue_free()
 await process_frame
 quit(1 if failures else 0)

