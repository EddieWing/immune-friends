extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://main.tscn").instantiate()
 g.save_path="user://test_camera_entry.json"
 root.add_child(g)
 await process_frame
 g.set_process(false)
 assert(is_equal_approx(g.view.scale.x,1.0))
 g.view.scale=Vector2.ONE*0.6;g.zoom_target=1.5
 g.enter_microscope(func():g.show_help())
 var position=g.view.position
 var radius=g.visor_radius
 assert(g.modal.visible and g.modal.modulate.a==0.0)
 for i in range(90):
  g.advance_camera(1.0/60)
  g.advance_visor(1.0/60)
  assert(is_equal_approx(g.view.scale.x,1.0))
  assert(g.view.position.is_equal_approx(position))
  assert(is_equal_approx(g.visor_radius,radius))
  await process_frame
 g.menu_transition.custom_step(2.0)
 g.advance_camera(1.0/60);g.advance_visor(1.0/60)
 assert(is_equal_approx(g.view.scale.x,1.0) and is_equal_approx(g.visor_radius,radius))
 assert(g.modal.visible and is_equal_approx(g.modal.modulate.a,1.0))
 print("PASS startup 1x; stale zoom cleared; camera/visor continuous; help fades with HUD")
 quit()
