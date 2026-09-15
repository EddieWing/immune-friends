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
 var menu_zoom=scene.zoom_target
 var menu_wheel=InputEventMouseButton.new()
 menu_wheel.position=Vector2(900,300)
 menu_wheel.pressed=true
 menu_wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 scene._unhandled_input(menu_wheel)
 scene.set_zoom(1.5)
 check(scene.zoom_target==menu_zoom,"main menu blocks wheel and slider zoom")
 scene.main_menu.hide()
 scene.entering_game=true
 scene.set_zoom(1.5)
 check(scene.zoom_target==menu_zoom,"microscope entrance blocks manual zoom")
 scene.entering_game=false
 scene.set_zoom(1.2)
 check(scene.zoom_target==1.2,"zoom is available after entering gameplay")
 scene.show_menu()
 check(scene.zoom_target==scene.view.scale.x,"opening menu cancels residual zoom easing")
 scene.main_menu.hide()
 var sources_sim=load("res://scripts/simulation.gd").new()
 sources_sim.reset(42,12)
 var original_sources=sources_sim.infection_sources.duplicate()
 var distances_ok=true
 for source in original_sources:
  var distance=source.distance_to(sources_sim.source_center)
  distances_ok=distances_ok and distance>=340 and distance<=440
 check(distances_ok,"infection sources respect configured distance range")
 sources_sim.make_wave()
 check(sources_sim.infection_sources==original_sources,"source positions are stable for the same seed and round")
 sources_sim.round_no=2
 sources_sim.make_wave()
 check(sources_sim.infection_sources!=original_sources,"next round randomizes source positions")
 sources_sim.begin_battle()
 sources_sim.spawn_queue.clear()
 sources_sim.spawn_virus({"lane":0,"type":"basic"})
 var emerging=sources_sim.viruses[0]
 var origin=emerging.p
 var exit_point=emerging.exit
 check(origin==sources_sim.infection_sources[0] and emerging.emerging,"virus begins inside its ink source")
 sources_sim.update(0.1)
 check(emerging.emerging and emerging.p.distance_to(exit_point)<origin.distance_to(exit_point),"virus first swims toward its spawn exit")
 for step in range(180):
  if not emerging.emerging: break
  sources_sim.update(1.0/60.0)
 check(not emerging.emerging and emerging.p.is_equal_approx(exit_point),"virus finishes emergence exactly at its generated spawn point")
 sources_sim.update(0.1)
 check(emerging.p!=exit_point,"normal movement begins after emergence")
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
 scene.speed_buttons[0].pressed.emit()
 check(scene.sim.phase=="battle" and scene.playback_speed==1,"Play starts preparation at normal speed")
 scene.advance_simulation(scene.LAUNCH_SECONDS)
 check(scene.sim.elapsed==0 and scene.launch_remaining==0,"launch delay does not consume simulated battle time")
 scene.speed_buttons[3].pressed.emit()
 var paused_time=scene.sim.elapsed
 scene.advance_simulation(0.1)
 check(scene.paused and scene.sim.elapsed==paused_time,"Pause freezes battle simulation")
 scene.speed_buttons[1].pressed.emit()
 scene.advance_simulation(0.1)
 check(not scene.paused and absf(scene.sim.elapsed-paused_time-0.2)<0.00001,"fast forward resumes at x2")
 scene.sim.reset(42,12)
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
 scene.sim.blood_links.clear()
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
 scene.sim.viruses=[]
 scene.sim.blood=[{"id":10,"p":Vector2.ZERO,"alive":true},{"id":20,"p":Vector2(26,0),"alive":true},{"id":30,"p":Vector2(52,0),"alive":true}]
 scene.sim.blood_links=[{"a":0,"b":1,"rest":26},{"a":1,"b":2,"rest":26}]
 faces.update(scene.sim,2.0)
 scene.sim.blood[0].alive=false
 scene.sim.record("blood_lost",{"id":10,"p":Vector2.ZERO})
 scene.sim.blood_links.clear()
 faces.update(scene.sim,0.016)
 check(faces.states[20].emotion=="crying","direct hand neighbour cries even after link cleanup")
 check(faces.states[30].emotion!="crying","crying does not spread to indirect neighbours")
 faces.update(scene.sim,3.1)
 check(faces.states[20].emotion=="calm","crying expires after configured duration")
 scene.queue_free()
 await process_frame
 print("RESULT: 16 checks, %d failures"%failures)
 quit(1 if failures else 0)


