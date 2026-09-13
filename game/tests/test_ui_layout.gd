extends SceneTree
var failures=0
func check(ok,message):
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func _initialize():
	call_deferred("run")
func run():
	var scene=load("res://main.tscn").instantiate()
	scene.save_path="user://ui_layout_test.json"
	root.add_child(scene)
	await process_frame
	for control in [scene.xp_button,scene.refresh_button,scene.freeze_button,scene.start_button]:
		check(is_equal_approx(control.size.x,control.size.y),"toolbar icon button stays square")
		check(scene.bottom_panel.get_global_rect().encloses(control.get_global_rect()),"toolbar button stays inside shelf")
	scene.modal.hide()
	scene.sim.reset(42,12)
	var before=scene.sim.blood.map(func(b): return b.p)
	scene.sim.move_blood(0,Vector2(100,60))
	var shift=scene.sim.blood[0].p-before[0]
	var coherent=true
	var separated=true
	for i in range(scene.sim.blood.size()):
		coherent=coherent and (scene.sim.blood[i].p-before[i]).is_equal_approx(shift)
		for j in range(i+1,scene.sim.blood.size()):
			separated=separated and scene.sim.blood[i].p.distance_to(scene.sim.blood[j].p)>25.99
	check(coherent,"dragging blood moves its connected cluster")
	check(separated,"blood membranes do not overlap")
	scene.refresh()
	check(not scene.detail_panel.visible,"no permanent card blocking field")
	var money=scene.sim.money
	scene.arm_offer(0,false)
	check(scene.sim.money==money and scene.sim.cells.is_empty(),"arming purchase does not spend money")
	scene.buy_offer_at(0,false,Vector2(210,-80))
	check(scene.sim.cells.size()==1 and scene.sim.cells[0].p==Vector2(210,-80),"purchase placed at requested location")
	check(scene.sim.money==money-2 and scene.pending_offer.is_empty(),"placement charges once and clears tool")
	scene.sim.rewards=["wall","wall","wall","wall","wall","wall","wall"]
	scene.shop_page=1
	scene.refresh()
	check(scene.shop.get_child_count()>0 and scene.previous_button.visible,"overflow rewards accessible on next page")
	scene.sim.rewards=[]
	scene.shop_page=0
	scene.refresh()
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/ui-preparation.png")
	scene.start_battle()
	check(not scene.bottom_panel.visible and not scene.currency_panel.visible,"battle clears shop shelf")
	scene.sim.phase="recap"
	scene.show_recap()
	var forecast=scene.preview_wave.duplicate(true)
	check(scene.shade.color.a==0 and scene.showing_recap,"recap leaves microscope visible")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/ui-recap.png")
	scene.advance_recap()
	check(scene.sim.wave==forecast and scene.bottom_panel.visible,"recap forecast matches next preparation")
	for screen in ["show_menu","show_settings","show_help","show_catalog","show_virus_catalog","show_reward"]:
		if screen=="show_reward": scene.sim.reward_choices=[["accelerator","tag_sprayer"]]
		scene.call(screen)
		for frame in range(5): await process_frame
		var window=scene.modal_panel
		check(Rect2(0,0,1440,900).encloses(window.get_global_rect()),screen+" fits inside the viewport")
		for child in window.get_child(0).get_children():
			check(window.get_global_rect().encloses(child.get_global_rect()),screen+" content stays inside window")
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://ui_layout_test.json")
	print("RESULT: layout checks, %d failures" % failures)
	quit(1 if failures else 0)
