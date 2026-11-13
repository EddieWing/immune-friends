extends Node
const Main=preload("res://main.tscn")
const Replay=preload("res://scripts/battle_replay.gd")
var checks=0
func check(ok,what):
 if not ok:push_error("LIFECYCLE FAIL: "+what);return false
 checks+=1;print("LIFECYCLE PASS: "+what);return true
func _ready():
 var g=Main.instantiate();g.settings_path="user://lifecycle_settings.cfg";g.save_path="user://lifecycle_save.json";add_child(g)
 await get_tree().process_frame
 g.main_menu.hide();g.modal.hide();g.entering_game=false;g.launch_remaining=0;g.gym_mode=true;g.sim.gym_mode=true;g.sim.cells.clear();g.sim.viruses.clear();g.sim.wave.clear();g.sim.spawn_queue.clear();g.sim.rebuild_links()
 var c=g.sim.make_cell("wall",Vector2(250,0));g.sim.cells.append(c);g.gym_run();g.set_playback_speed(5)
 await get_tree().create_timer(2.0).timeout
 var started=g.sim.elapsed;check(started>1.0 and g.battle_worker!=null,"worker advances Gym at ×5")
 g.paused=true;await get_tree().create_timer(0.5).timeout
 var frozen=g.sim.elapsed;var old_id=g.sim.next_id;await get_tree().create_timer(0.7).timeout
 check(g.battle_worker==null and is_equal_approx(frozen,g.sim.elapsed),"pause stops worker and restores state")
 var extra=g.sim.make_cell("wall",Vector2(-300,-200));g.sim.cells.append(extra);g.sim.money+=10;var money=g.sim.money;var added_id=extra.id
 g.paused=false;await get_tree().create_timer(0.7).timeout
 g.paused=true;await get_tree().create_timer(0.5).timeout
 check(g.sim.elapsed>frozen and not g.sim.cell_by_id(added_id).is_empty() and g.sim.money==money and g.sim.next_id==old_id+1,"paused edits persist across resume and second pause")
 var prior=g.sim.elapsed;g.sim.update(1.0/60);check(is_equal_approx(g.sim.elapsed,prior+1.0/60),"single debug step runs while stopped")
 g.gym_mode=false;g.sim.gym_mode=false;g.sim.reset(913,12);g.sim.cells.clear();g.sim.cells.append(g.sim.make_cell("turret",Vector2(180,0)));g.sim.rebuild_links();g.battle_replay.start(g.sim);g.sim.begin_battle();g.paused=false;g.set_playback_speed(5);g.clock_phase="shop";g.last_phase="battle"
 var remaining=25.0
 while g.sim.phase=="battle" and remaining>0:
  await get_tree().create_timer(0.25).timeout;remaining-=0.25
 check(g.sim.phase=="recap" and g.battle_worker==null,"ordinary battle reaches recap and restores state")
 var replay=g.battle_replay.last;check(not replay.is_empty() and int(replay.get("ticks",0))>0,"replay records exact completed battle")
 if not replay.is_empty():
  var opened=Replay.open(replay)
  if check(not opened.has("error"),"recorded replay opens"):
   var s=opened.sim
   for i in range(int(replay.ticks)):s.update(1.0/60)
   check(Replay.outcome(s)==replay.outcome,"replay reproduces recorded battle outcome")
 print("LIFECYCLE COMPLETE checks=",checks)
 g.queue_free()
