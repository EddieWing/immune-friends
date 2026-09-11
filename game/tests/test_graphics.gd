extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize():
 call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://graphics-test.cfg"
 scene.save_path="user://graphics-test.json"
 root.add_child(scene)
 await process_frame
 scene.modal.hide()
 scene.set_graphics_style(0)
 var seed_value=scene.sim.seed_value
 var money=scene.sim.money
 var round_no=scene.sim.round_no
 var simple=scene.cell_icon("wall")
 var all_valid=true
 for mode in [0,1]:
  scene.set_graphics_style(mode)
  for key in scene.sim.catalog:
   var icon=scene.cell_icon(key)
   all_valid=all_valid and icon.get_width()==128 and icon.get_height()==128
   var body=scene.visuals.body(key,scene.sim.catalog[key]).get_image()
   all_valid=all_valid and body.get_pixel(0,0).a<0.01
 check(all_valid,"all 27 cell types have valid transparent icons in both styles")
 check(simple!=scene.cell_icon("wall"),"switching style invalidates icon cache")
 check(scene.sim.money==money and scene.sim.round_no==round_no and scene.sim.seed_value==seed_value,"graphics switch preserves game state")
 var config=ConfigFile.new()
 config.load(scene.settings_path)
 check(config.get_value("graphics","style",-1)==1,"graphics preference persisted")
 check(scene.view.visuals==scene.visuals,"field and shop use the same visual style")
 if "--capture" in OS.get_cmdline_user_args():
  scene.sim.cells.clear()
  for i in range(8):
   var key=scene.visuals.ARCHETYPES[i]
   scene.sim.cells.append(scene.sim.make_cell(key,Vector2(-200+(i%4)*135,-130+int(i/4)*180)))
  scene.sim.rebuild_links()
  for mode in [0,1]:
   scene.set_graphics_style(mode)
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://artifacts/style-%d.png"%mode)
 scene.queue_free()
 await process_frame
 DirAccess.remove_absolute("user://graphics-test.cfg")
 DirAccess.remove_absolute("user://graphics-test.json")
 print("RESULT: 5 checks, %d failures"%failures)
 quit(1 if failures else 0)
