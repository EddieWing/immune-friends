extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
 var sim=preload("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 var director=preload("res://scripts/camera_director.gd").new()
 var safe=Rect2(200,100,1000,600)
 var initial=director.frame(sim,"battle",safe,1.5)
 sim.viruses=[{"alive":true,"p":Vector2(10000,10000)}]
 var distant=director.frame(sim,"battle",safe,1.5)
 check(initial.is_empty() and not distant.is_empty() and distant.zoom==1.5,"Only threats create interest; distant viruses are included without changing zoom")
 var warning=director.frame(sim,"warning",safe,0.88,[Vector2(-800,100)])
 check(warning.focus==Vector2(-800,100),"forecast frames selected threat")

 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://microscope_test_settings.cfg"
 scene.save_path="user://microscope_test_run.json"
 root.add_child(scene)
 await process_frame
 scene.main_menu.hide()
 scene.modal.hide()
 scene.set_process(false)
 scene.auto_camera=true
 scene.view.staging=""
 scene.sim.phase="shop"
 scene.set_zoom(0.97)
 scene.view.scale=Vector2.ONE*0.97
 check(scene.set_automatic_zoom(scene.camera_director.ZoomLevel.CLOSE),"Automatic camera can request named close zoom")
 check(is_equal_approx(scene.view.scale.x,0.97) and scene.zoom_target==1.5 and scene.camera_requested==0.97,"Automatic target preserves current scale and player preference")
 scene.advance_camera(0.01)
 check(scene.view.scale.x>0.97 and scene.view.scale.x<1.5,"Automatic zoom interpolates instead of snapping")
 check(not scene.set_automatic_zoom(99) and scene.zoom_target==1.5,"Invalid level leaves camera state intact")
 scene.set_zoom(1.03)
 check(scene.zoom_target==1.03 and scene.camera_requested==1.03 and scene.auto_camera,"Manual zoom interrupts preset with a non-discrete value and keeps Auto")
 for step in range(100):scene.advance_camera(0.01)
 check(is_equal_approx(scene.view.scale.x,1.03),"Manual target wins after automatic transition")
 scene.set_zoom(1.5)
 check(scene.auto_camera,"manual zoom retains Auto")
 scene.set_process(false)
 scene.zoom_gauge.auto_button.button_pressed=false
 scene.zoom_gauge.auto_button.button_pressed=true
 check(scene.auto_camera,"Auto button enables tracking")
 var arrow=InputEventKey.new()
 arrow.physical_keycode=KEY_RIGHT
 arrow.keycode=KEY_RIGHT
 arrow.pressed=true
 Input.parse_input_event(arrow)
 Input.flush_buffered_events()
 var arrow_before=scene.view.position
 scene.advance_manual_camera(0.5)
 arrow=arrow.duplicate()
 arrow.pressed=false
 Input.parse_input_event(arrow)
 Input.flush_buffered_events()
 check(not scene.auto_camera and scene.view.position.x<arrow_before.x,"Arrow key pans and disables Auto")
 scene.auto_camera=true
 scene.dragging_blood=0
 arrow_before=scene.view.position
 scene.advance_manual_camera(1,Vector2.LEFT)
 check(scene.view.position==arrow_before and scene.auto_camera,"Dragging a cell blocks keyboard pan")
 scene.dragging_blood=-1
 scene.auto_camera=true

 var event=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT
 event.position=Vector2(700,400)
 event.pressed=true
 scene._unhandled_input(event)
 check(not scene.auto_camera,"manual pan suspends Auto")
 scene.set_process(false)
 var camera_before=scene.view.position
 var core_before=scene.sim.blood.duplicate(true)
 var motion=InputEventMouseMotion.new()
 motion.position=Vector2(770,440)
 scene._input(motion)
 check(scene.view.position==camera_before+Vector2(70,40) and scene.sim.blood==core_before,"Right drag moves the camera without moving the formation")
 event.pressed=false
 event.position=Vector2(50,30)
 scene.modal.show()
 scene._input(event)
 check(not scene.panning,"Right release over UI always ends camera dragging")
 scene.modal.hide()
 camera_before=scene.view.position
 scene.advance_manual_camera(1,Vector2(-1,0))
 check(scene.view.position==camera_before+Vector2(-280,0),"WASD direction pans in preparation")
 camera_before=scene.view.position
 scene.advance_manual_camera(1,Vector2(-1,-1))
 check(is_equal_approx(scene.view.position.distance_to(camera_before),280),"Diagonal camera speed matches axial movement")
 scene.main_menu.show()
 camera_before=scene.view.position
 scene.advance_manual_camera(1,Vector2.LEFT)
 scene.begin_camera_pan(Vector2(700,400))
 check(scene.view.position==camera_before and not scene.panning,"Main menu blocks camera navigation")
 scene.main_menu.hide()
 var input=LineEdit.new()
 scene.ui.add_child(input)
 input.grab_focus()
 scene.advance_manual_camera(1,Vector2.LEFT)
 check(scene.view.position==camera_before,"Typing into an input does not move the camera")
 input.release_focus()
 input.queue_free()
 scene.begin_camera_pan(Vector2(700,400))
 scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not scene.panning,"Losing window focus cancels right drag")
 scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
 scene.auto_camera=true
 scene.panning=false
 scene.sim.phase="shop"
 scene.view.staging=""
 for core in scene.sim.blood: core.p+=Vector2(250,-170)
 scene.center_preparation_camera()
 var center=Vector2.ZERO
 var count=0
 for core in scene.sim.blood:
  if core.alive:
   center+=core.p
   count+=1
 center/=float(count)
 check(scene.view.to_global(center).is_equal_approx(scene.board_rect.get_center()),"Preparation centers living Core once")
 scene.advance_manual_camera(1,Vector2.LEFT)
 camera_before=scene.view.position
 scene.advance_camera(0.25)
 scene.changed()
 check(scene.view.position.is_equal_approx(camera_before),"Preparation releases camera after centering")
 scene.auto_camera=false
 scene.view.position=scene.board_rect.get_center()
 scene.view.scale=Vector2.ONE*1.5
 scene.zoom_target=1.5
 scene.advance_camera(2)
 var focused_radius=scene.visor_radius
 scene.view.position+=Vector2(1400,900)
 scene.advance_camera(2)
 check(scene.visor_radius>focused_radius,"Leaving start focus opens visor")
 scene.view.position=scene.board_rect.get_center()
 scene.view.scale=Vector2.ONE*1.5
 scene.zoom_target=1.5
 scene.advance_camera(2)
 var small=scene.visor_radius
 scene.sim.phase="battle"
 scene.set_automatic_zoom(1)
 scene.advance_camera(2)
 check(scene.visor_radius>small,"Launch medium magnification opens visor")
 scene.show_menu()
 scene.advance_visor(1.0)
 check(scene.ui.get_node("MicroscopeVignette").material.get_shader_parameter("visibility")==0.0,"menu hides visor")
 scene.main_menu.hide()
 scene.background_motion=0
 var clock=scene.water_time
 scene.advance_camera(0.25)
 check(scene.water_time==clock,"zero background motion freezes fluid")
 scene.show_visual_comfort()
 scene.sim.phase="battle"
 var settings_time=scene.sim.elapsed
 scene.advance_simulation(0.1)
 check(scene.sim.elapsed==settings_time,"settings inspection pauses battle without changing playback preference")
 var slider=scene.modal.find_child("Comfort_optics",true,false)
 slider.value=0.2
 check(is_equal_approx(scene.optical_intensity,0.2),"comfort control changes optical intensity")
 var config=ConfigFile.new()
 config.load(scene.settings_path)
 check(is_equal_approx(config.get_value("comfort","optics",-1),0.2),"comfort setting persists")
 var fx=preload("res://scripts/microscope_effects.gd").new()
 sim.phase="battle"
 sim.viruses=[{"alive":true,"p":Vector2.ZERO,"id":123}]
 fx.update(sim,0.01)
 for i in range(500):
  sim.elapsed+=0.001
  sim.viruses[0].p.x+=6
  fx.update(sim,0.001)
 check(fx.trails.size()<=420 and fx.trails.size()>0,"dense trails are bounded")
 var age=fx.trails[0].age
 fx.update(sim,1.0)
 check(fx.trails[0].age==age,"paused simulation freezes trails")
 sim.phase="shop"
 fx.update(sim,4.0)
 check(fx.trails.is_empty(),"aftermath trails expire")
 DirAccess.remove_absolute(scene.settings_path)
 scene.queue_free()
 await process_frame
 quit(1 if failures else 0)
