extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize():call_deferred("run")
func click_named(node,caption):
 for child in node.get_children():
  if child is Button and child.text==caption:
   child.pressed.emit()
   return true
  if click_named(child,caption):return true
 return false
func run():
 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://functional_cycle_test.cfg"
 scene.save_path="user://functional_cycle_test.json"
 DirAccess.remove_absolute(scene.settings_path)
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.main_menu.hide()
 scene.menu_open=false
 scene.modal.hide()
 for i in range(12):await process_frame
 scene.hud_a._process(0.4)
 check(scene.hud_a.note.size.y<240,"Initial short threat panel fits its content without buying a cell")
 scene.sim.money=0
 scene.hud_a._process(0)
 check(scene.hud_a.refresh_button.disabled and scene.hud_a.refresh_button.get_theme_stylebox("disabled").corner_radius_top_left==28,"Unavailable refresh keeps its circular shape")
 for outcome in ["lose","win"]:
  scene.sim.phase=outcome
  scene.results_pending=false
  scene.show_infection_results()
  check(scene.modal.visible and scene.results_stage=="losses","Terminal "+outcome+" presents losses first")
  check(click_named(scene.modal,"OK"),"Loss report has OK")
  check(scene.results_stage=="finished","OK opens run result without next-wave forecast")
  check(click_named(scene.modal,"Main menu"),"Run result returns to menu")
  check(scene.menu_open and not scene.modal.visible,"Menu hides the report")
  check(click_named(scene.main_menu,"Continue"),"Continue exists after completed run")
  await create_timer(1.4).timeout
  check(scene.modal.visible and scene.results_stage=="finished" and not scene.menu_open,"Continue restores "+outcome+" result instead of an empty field")
 scene.new_run(12)
 check(scene.sim.phase=="shop" and scene.sim.round_no==1 and scene.shopping_in_focus(),"Restart returns to first preparation with an open shop")
 scene.modal.hide()
 scene.save_run()
 scene.sim.phase="recap"
 scene.show_recap()
 scene.load_run()
 scene.hud_a._process(0.4)
 check(scene.sim.phase=="shop" and not scene.hud_a.forecast.visible and scene.results_stage=="","Loading preparation dismisses the previous forecast")
 scene.queue_free()
 await process_frame
 DirAccess.remove_absolute("user://functional_cycle_test.cfg")
 DirAccess.remove_absolute("user://functional_cycle_test.json")
 print("RESULT: functional cycle, %d failures" % failures)
 quit(1 if failures else 0)
