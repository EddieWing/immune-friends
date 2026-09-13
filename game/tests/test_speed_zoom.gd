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
 check(scene.view.scale.x<scene.zoom_target,"zoom has a short easing tail")
 scene.advance_camera(1.0)
 check(is_equal_approx(scene.view.scale.x,1.5) and scene.zoom_gauge.visible,"wheel reaches maximum zoom and gauge is visible")
 wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
 for i in range(40): scene._unhandled_input(wheel)
 scene.advance_camera(1.0)
 check(is_equal_approx(scene.background_material.get_shader_parameter("camera_zoom"),scene.view.scale.x),"background follows camera zoom")
 check(scene.water_time>0,"water animates during preparation")
 check(is_equal_approx(scene.view.scale.x,0.45),"wheel respects minimum zoom")
 var faces=preload("res://scripts/blood_faces.gd").new()
 scene.sim.reset(42,12)
 scene.sim.blood=[{"id":0,"p":Vector2.ZERO,"alive":true}]
 scene.sim.phase="battle"
 var enemy={"id":99,"p":Vector2(120,0),"alive":true,"type":"basic","age":0.0,"jump":false,"tag":0.0,"hp":1.0}
 scene.sim.viruses=[enemy]
 faces.update(scene.sim,0.016)
 check(faces.states[0].emotion=="surprised" and faces.states[0].look.x>0 and faces.states[0].look.x<1,"visible virus triggers surprise and eased gaze")
 enemy.p=Vector2(40,0)
 faces.update(scene.sim,0.016)
 check(faces.states[0].emotion=="scared","close virus triggers fear")
 enemy.p=Vector2(120,0)
 faces.update(scene.sim,2.0)
 enemy.alive=false
 scene.sim.record("virus_defeated",{"id":99,"p":enemy.p})
 faces.update(scene.sim,0.016)
 check(faces.states[0].emotion=="relieved","tracked virus death triggers relief")
 faces.update(scene.sim,2.0)
 check(faces.states[0].emotion=="calm","emotion expires without a threat")
 enemy.alive=true
 var wall=scene.sim.make_cell("wall",Vector2(60,0))
 wall.angle=PI/2
 scene.sim.cells=[wall]
 faces.update(scene.sim,0.016)
 check(faces.states[0].target==-1,"wall blocks line of sight")
 scene.sim.cells=[]
 scene.sim.record("cell_rest",{"id":123,"p":Vector2(50,20)})
 faces.update(scene.sim,0.016)
 check(faces.states[0].emotion=="scared","visible friendly death triggers fear")
 scene.queue_free()
 await process_frame
 print("RESULT: 16 checks, %d failures"%failures)
 quit(1 if failures else 0)

