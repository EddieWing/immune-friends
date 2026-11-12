extends SceneTree
# Isolated playable fixture; no player save/settings are read or overwritten.
func _initialize():call_deferred('run')
func run():
 var scene=load('res://main.tscn').instantiate()
 scene.save_path='user://atlas_integration_preview.json'
 scene.settings_path='user://atlas_integration_preview.cfg'
 root.add_child(scene)
 scene.new_run(12,3)
 scene.main_menu.hide();scene.modal.hide()
 var names=['wall','tackle','seeker','orbiter','regen','sniper','generator','bandage']
 for i in names.size():
  var body=scene.sim.make_cell(names[i],Vector2.from_angle(i*TAU/names.size())*160)
  scene.sim.cells.append(body)
 scene.sim.rebuild_links()
 scene.refresh()
 DisplayServer.window_set_title('Primordial Soup — animation integration test')
