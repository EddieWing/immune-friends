extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://graphics-test.cfg"
 scene.save_path="user://graphics-test.json"
 var legacy=ConfigFile.new()
 legacy.set_value("graphics","style",1)
 legacy.save(scene.settings_path)
 root.add_child(scene)
 await process_frame
 var all_valid=true
 for key in scene.sim.catalog:
  var icon=scene.cell_icon(key)
  all_valid=all_valid and icon.get_width()==128 and icon.get_height()==128
  all_valid=all_valid and scene.visuals.body(key,scene.sim.catalog[key]).get_image().get_pixel(0,0).a<0.01
 check(all_valid,"all 27 cells use valid transparent simple graphics")
 var config=ConfigFile.new()
 config.load(scene.settings_path)
 check(not config.has_section("graphics"),"legacy painted preference removed")
 check(scene.view.visuals==scene.visuals,"field and atlas share simple graphics")
 scene.queue_free()
 await process_frame
 DirAccess.remove_absolute("user://graphics-test.cfg")
 DirAccess.remove_absolute("user://graphics-test.json")
 quit(1 if failures else 0)
