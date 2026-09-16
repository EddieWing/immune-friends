extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate()
 scene.save_path="user://gym-isolation-%d.json" % Time.get_ticks_usec()
 scene.settings_path="user://gym-test.cfg"
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 var original=scene.sim
 var original_money=original.money
 var original_blood=original.blood.duplicate(true)
 scene.enter_gym()
 scene.main_menu.hide()
 check(scene.sim!=original and scene.sim.gym_mode,"Gym uses an isolated simulation")
 check(scene.lab_tools.cell_keys.size()==scene.sim.available_cell_keys().size()+1 and scene.lab_tools.virus_keys.size()==7,"Gym exposes every immune cell plus core cells and every virus")
 for key in scene.sim.available_cell_keys():
  scene.gym_tool={"kind":"cell","key":key,"rank":3}
  scene.gym_place(Vector2(180,0))
 check(scene.sim.cells.size()==scene.sim.available_cell_keys().size() and scene.sim.cells.all(func(c): return c.rank==3),"all cell types can be placed as elites without economy limits")
 scene.gym_clear()
 for key in scene.lab_tools.virus_keys:
  scene.gym_tool={"kind":"virus","key":key,"rank":1}
  scene.gym_place(Vector2(250,0))
 check(scene.sim.viruses.size()==7 and scene.sim.viruses.all(func(v): return not v.emerging),"all viruses spawn at the chosen position")
 scene.gym_tool={}
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=scene.view.to_global(Vector2(250,0))
 scene._unhandled_input(click)
 check(not scene.detail_panel.visible,"single click on a virus does not open its card")
 click.double_click=true
 scene._unhandled_input(click)
 check(scene.detail_panel.visible and not scene.inspected_virus.is_empty(),"double click opens the virus card")
 click.double_click=false
 click.position=Vector2(650,600)
 scene._unhandled_input(click)
 check(not scene.detail_panel.visible,"clicking the field closes the inspected card")
 scene.gym_tool={"kind":"cell","key":"wall","rank":1}
 scene.gym_place(Vector2(160,0))
 var start=scene.sim.cells[0].p
 scene.gym_run()
 scene.sim.update(0.1)
 check(scene.sim.phase=="battle" and scene.sim.spawn_queue.is_empty(),"Gym runs without automatic wave spawning")
 scene.paused=true
 var before=scene.sim.elapsed
 scene.advance_simulation(0.1)
 check(scene.sim.elapsed==before,"Gym pause stops simulation")
 scene.gym_reset_setup()
 check(scene.sim.phase=="shop" and scene.sim.cells[0].p==start and scene.sim.viruses.size()==7,"Reset restores the pre-test setup")
 scene.gym_clear()
 scene.gym_run()
 scene.sim.update(0.1)
 check(scene.sim.phase=="battle","empty Gym does not trigger victory")
 for core in scene.sim.blood: core.alive=false
 scene.sim.update(0.1)
 check(scene.sim.phase=="battle","loss of core cells does not exit Gym")
 scene.save_run()
 check(not FileAccess.file_exists(scene.save_path),"Gym never writes a campaign save")
 scene.leave_gym()
 check(scene.sim==original and scene.sim.money==original_money and scene.sim.blood==original_blood,"leaving Gym preserves the original run")
 var key=InputEventKey.new()
 key.keycode=KEY_F3
 key.pressed=true
 scene._input(key)
 check(scene.lab_tools.debug_panel.visible,"F3 opens debug tools")
 scene._input(key)
 check(not scene.lab_tools.debug_panel.visible,"F3 closes debug tools")
 scene.queue_free()
 await process_frame
 print("RESULT: Gym and debug checks, %d failures" % failures)
 quit(1 if failures else 0)
