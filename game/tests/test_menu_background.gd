extends SceneTree
func _initialize():call_deferred("run")
func run():
	var g=load("res://main.tscn").instantiate()
	g.save_path="user://regression_menu.json"
	g.settings_path="user://regression_menu.cfg"
	root.add_child(g)
	await process_frame
	g.set_process(false)
	var background=g.main_menu.get_child(0)
	if background is TextureRect:
		assert(background.material==g.background_material,"Menu uses the animated water material")
	else:
		assert(background.color.a<0.8,"Menu must reveal the animated water backdrop")
		assert(is_zero_approx(g.view.modulate.a),"Only backdrop, not gameplay objects, shows through menu")
	var before=g.water_time
	g.advance_camera(0.1)
	assert(g.water_time>before,"Water animation remains active in menu")
	g.hud_opacity=1;g.apply_menu_visibility()
	assert(is_equal_approx(g.view.modulate.a,1),"Gameplay objects return with HUD")
	print("PASS menu reveals animated background and fades gameplay objects")
	quit()
