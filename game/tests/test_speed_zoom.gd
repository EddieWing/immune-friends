extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://speed-test.cfg"
 scene.save_path="user://speed-test.json"
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.modal.hide()
 var final_positions=[]
 for speed in [1,2,5]:
  scene.sim.reset(42,12)
  scene.sim.begin_battle()
  scene.clock_accum=0
  scene.set_playback_speed(speed)
  scene.advance_simulation(0.1)
  check(absf(scene.sim.elapsed-0.1*speed)<0.00001,"battle speed x%d advances correct simulated time"%speed)
 for speed in [1,5]:
  scene.sim.reset(42,12)
  scene.sim.begin_battle()
  scene.clock_accum=0
  scene.set_playback_speed(speed)
  for i in range(5 if speed==1 else 1): scene.advance_simulation(0.1)
  final_positions.append(scene.sim.viruses[0].p)
 check(final_positions[0].is_equal_approx(final_positions[1]),"speed does not change trajectory at equal simulated time")
 scene.sim.reset(42,12)
 var elapsed_before=scene.sim.elapsed
 scene.advance_simulation(0.1)
 check(scene.sim.phase=="shop" and scene.sim.elapsed==elapsed_before,"preparation remains untimed at x5")
 var wheel=InputEventMouseButton.new()
 wheel.position=Vector2(900,300)
 wheel.pressed=true
 wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 for i in range(30): scene._unhandled_input(wheel)
 check(is_equal_approx(scene.view.scale.x,1.5) and scene.zoom_gauge.visible,"wheel reaches maximum zoom and gauge is visible")
 wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
 for i in range(40): scene._unhandled_input(wheel)
 check(is_equal_approx(scene.view.scale.x,0.45),"wheel respects minimum zoom")
 scene.queue_free()
 await process_frame
 print("RESULT: 7 checks, %d failures"%failures)
 quit(1 if failures else 0)
