extends SceneTree
var failures=0
var checks=0
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate()
	game.save_path="user://test_greed_ui_checkpoint.json"
	game.settings_path="user://test_greed_ui_settings.cfg"
	root.add_child(game)
	await process_frame
	game.settings.set_value("tutorial","disabled",true)
	game.modal.hide();game.menu_open=false;game.main_menu.hide()
	game.entering_game=false;game.hud_opacity=1.0;game.apply_menu_visibility()
	for rank in [1,3]:
		game.sim.reset(164,12)
		var sim=game.sim
		var c=sim.make_cell("greed_wall",Vector2(200,0))
		c.rank=rank;c.max_hp=9;c.hp=9
		sim.cells=[c];sim.money=5
		game.gym_mode=false;game.paused=true
		var expected=10 if rank==1 else 20
		game.save_run()
		var checkpoint=FileAccess.get_file_as_string(game.save_path)
		sim.reset(165,12);game.load_run();c=sim.cells[0]
		check(c.hp==9 and c.max_hp==9 and sim.money==5,"File load restores preparation, not forecast HP")
		for stage in ["preparation","infection","restored"]:
			if stage=="infection":sim.begin_battle();sim.damage_cell(c,3,false,{"kind":"virus","id":123,"p":Vector2(250,0)})
			elif stage=="restored":sim.phase="recap";sim.next_round()
			game.paused=true;game.selected=c
			for appearance in [true,false]:
				game.ui_new=appearance;game.apply_appearance()
				game.inspected_cell=c.id;game.show_cell_card(c.key,c)
				await process_frame
				var text=game.hud_a.facts_text.text if appearance else game.detail.text
				check(text.contains("Permanent HP: 9"),"Both UI styles show permanent HP")
				if stage=="infection":
					check(text.contains("Current HP: %d"%(expected-3)),"Both UI styles show damage after conversion")
					check(text.contains("HP set at infection start: %d"%expected),"Both UI styles show original assigned HP")
				else:
					check(text.contains("Current HP: 9"),"Preparation shows restored current HP")
					check(text.contains("Next infection starts at:"),"Preparation shows replacement forecast")
			if stage=="infection":
				game.save_run()
				check(FileAccess.get_file_as_string(game.save_path)==checkpoint,"Battle save cannot overwrite preparation")
		game.save_run();sim.reset(166,12);game.load_run();c=sim.cells[0]
		check(c.hp==9 and c.max_hp==9 and not c.has("initial_conversion_health"),"Next preparation file excludes expired conversion")
		game.gym_mode=true;sim.money=5;game.paused=true
		game.gym_run();game.paused=true
		check(c.hp==expected and c.max_hp==9,"Gym Run applies same replacement")
		sim.heal(c,3);game.gym_run();game.paused=true
		check(c.hp==expected+3,"Gym Resume does not apply replacement again")
		game.gym_reset_setup();game.paused=true;c=sim.cells[0]
		check(c.hp==9 and not c.has("initial_conversion_health"),"Gym Reset restores permanent preparation")
		game.gym_run();game.paused=true
		check(c.hp==expected,"Repeated Gym run converts once again")
	game.queue_free();await process_frame
	for file in ["user://test_greed_ui_checkpoint.json","user://test_greed_ui_settings.cfg"]:
		if FileAccess.file_exists(file):DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("Greed UI/save/Gym: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
