extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
 var plan=preload("res://scripts/infection_plan.gd").new()
 var scale=plan.WORLD_SCALE
 var points=plan.slots(0,80,1)
 check(points.size()==50,"Reference layer 1 has 50 slots")
 check(absf(points[0].length()/scale-92.927092908)<0.0001,"First source reference distance 92.927092908")
 check(absf(points[1].length()/scale-95.808993026)<0.0001,"Second source reference distance 95.808993026")
 check(points[0].distance_to(Vector2(91.471528727,16.383040886)*scale)<0.001,"Reference coordinates with canvas Y inversion")
 check(plan.slots(90,60,0).size()==24 and plan.slots(45,70,2).size()==68,"Reference inner/outer slot counts")
 var sim=preload("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 check(sim.source_emitters.size()==2 and sim.wave[0].count==2,"Two independent emitters in first round")
 var positions=sim.source_emitters.map(func(e):return e.p)
 sim.blood[0].p=Vector2(500,700)
 sim.make_wave()
 check(positions==sim.source_emitters.map(func(e):return e.p),"Moving Core does not move source origin")
 sim.round_no=2
 sim.make_wave()
 check(sim.source_emitters[0].p==positions[0] and sim.source_emitters[1].p==positions[1],"Growth keeps existing source slots")
 check(sim.wave[0].count==4,"Round two adds two emissions")
 for r in range(1,13):
  sim.round_no=r
  sim.make_wave()
  var total=0
  for entry in sim.wave:total+=entry.count
  var expected=0
  for i in range(r):expected+=plan.GROWTH[i]
  check(total==expected,"Reference growth budget round %d"%r)
  check(sim.source_emitters.all(func(e):return e.cooldown>=1 and e.cooldown<2 and e.delay>=1),"Independent cooldown/delay round %d"%r)
 var snapshot=sim.source_emitters.duplicate(true)
 sim.make_wave()
 check(snapshot==sim.source_emitters,"Round replay is deterministic and idempotent")
 var delays=[]
 for emitter in sim.source_emitters:
  if not delays.has(emitter.delay): delays.append(emitter.delay)
 delays.sort()
 check(delays[0]==1.0,"Earliest group starts after one second")
 var valid_gaps=true
 for i in range(1,delays.size()): valid_gaps=valid_gaps and delays[i]-delays[i-1] in [3.0,6.0]
 check(valid_gaps,"Groups stagger by three seconds, plus three when direction changes")
 sim.begin_battle()
 var scheduled=sim.spawn_queue.duplicate(true)
 check(scheduled.size()==102,"All 102 emissions scheduled for round twelve")
 var independent=true
 for emitter in sim.source_emitters:
  var releases=scheduled.filter(func(e):return e.p==emitter.p)
  for i in range(1,releases.size()): independent=independent and absf(releases[i].due-releases[i-1].due-emitter.cooldown)<0.00001
 check(independent,"Each emitter retains its own repeat interval")
 sim.reset(42,12)
 sim.begin_battle()
 sim.elapsed=0.99
 sim.advance_spawns(0)
 check(sim.viruses.is_empty(),"No early first release")
 sim.elapsed=1.0
 sim.advance_spawns(0)
 check(sim.viruses.size()==2 and sim.spawn_queue.is_empty(),"Independent sources release simultaneously after one second")
 check(sim.viruses[0].p==positions[0] and not sim.viruses[0].emerging,"Birth at exact slot, ordinary movement immediately")
 sim.viruses.clear()
 sim.spawn_queue=[{"type":"basic","lane":0,"p":positions[0],"due":1.5},{"type":"basic","lane":0,"p":positions[1],"due":1.75}]
 sim.elapsed=2
 sim.advance_spawns(0)
 check(sim.viruses.size()==2,"A delayed update drains every due independent release")
 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://source-placement.cfg"
 scene.save_path="user://source-placement.json"
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.sim.reset(42,12)
 scene.sim.phase="recap"
 scene.show_recap()
 var preview=scene.preview_sources.duplicate()
 scene.sim.next_round()
 check(preview==scene.sim.infection_sources,"Forecast matches next round layout")
 quit(1 if failures else 0)
