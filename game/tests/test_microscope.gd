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
 check(initial==distant,"distant enemies cannot pull camera away from core")
 var warning=director.frame(sim,"warning",safe,0.88,[Vector2(-800,100)])
 check(warning.focus==Vector2(-800,100),"forecast frames selected threat")
 for b in sim.blood:
  if b.alive: check(safe.has_point(b.p*initial.zoom+initial.position),"core stays inside safe frame")
 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://microscope_test_settings.cfg"
 scene.save_path="user://microscope_test_run.json"
 root.add_child(scene)
 await process_frame
 scene.main_menu.hide()
 scene.modal.hide()
 scene.auto_camera=true
 scene.set_zoom(1.5)
 check(scene.auto_camera,"manual zoom retains Auto")
 var event=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT
 event.position=Vector2(700,400)
 event.pressed=true
 scene._unhandled_input(event)
 check(not scene.auto_camera,"manual pan suspends Auto")
 scene.auto_button.pressed.emit()
 check(scene.auto_camera,"Auto button resumes tracking")
 scene.panning=false
 scene.sim.phase="shop"
 scene.visor_radius=0.54
 scene.advance_visor(1.0)
 var small=scene.visor_radius
 scene.sim.phase="battle"
 scene.advance_visor(1.0)
 check(scene.visor_radius>small,"battle expands visor independently of zoom")
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
