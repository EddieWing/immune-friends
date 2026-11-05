extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate()
	game.settings_path="user://test_tutorial.cfg"
	game.save_path="user://test_tutorial.json"
	root.add_child(game)
	await process_frame
	game.main_menu.hide()
	game.modal.hide()
	game.sim.reset(42,12)
	var guide=game.tutorial_guide
	guide.begin()
	game.sim.money=0
	game.sim.offers=["wall"]
	game.buy_offer_at(0,false,Vector2(220,0))
	assert(not guide.done.has("purchase"))
	game.sim.money=6
	game.buy_offer_at(0,false,Vector2(220,0))
	assert(guide.done.has("purchase") and guide.done.has("place"))
	var wall=game.sim.cells[0]
	wall.p+=Vector2(40,0)
	guide.observe()
	assert(not guide.done.has("rotate"))
	wall.angle+=0.3
	guide.observe()
	assert(guide.done.has("rotate"))
	game.advance_manual_camera(0.1,Vector2.RIGHT)
	game.set_zoom(0.7)
	assert(guide.done.has("pan") and guide.done.has("zoom"))
	game.sim.money=0
	game.sim.buy_xp()
	guide.observe()
	assert(not guide.done.has("xp"))
	game.sim.money=6
	game.sim.buy_xp()
	guide.observe()
	assert(guide.done.has("xp"))
	var second=game.sim.make_cell("wall",wall.p)
	game.sim.cells.append(second)
	game.sim.merge(wall,second)
	guide.observe()
	assert(not guide.done.has("merge"))
	var third=game.sim.make_cell("wall",wall.p)
	game.sim.cells.append(third)
	game.sim.merge(wall,third)
	guide.observe()
	assert(guide.done.has("merge"))
	game.sim.reward_choices=[]
	var bond=game.sim.make_cell("bond",wall.p+Vector2(30,0))
	game.sim.cells.append(bond)
	game.changed()
	assert(guide.done.has("bonds"))
	var before=guide.capture()
	game.save_run()
	guide.done={}
	game.load_run()
	assert(guide.capture()==before)
	game.start_battle()
	guide.observe()
	assert(guide.done.has("launch"))
	game.sim.phase="recap"
	game.sim.next_round()
	guide.refresh_hint()
	assert(guide.current=="free_xp")
	guide.complete("free_xp")
	assert(not guide.active)
	var cells=game.sim.cells.size()
	var money=game.sim.money
	guide.begin()
	assert(game.sim.cells.size()==cells and game.sim.money==money)
	guide.skip()
	assert(not guide.active and game.settings.get_value("tutorial","disabled"))
	guide.begin()
	game.gym_mode=true
	guide.complete("pan")
	assert(not guide.done.has("pan"))
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test_tutorial.cfg")
	DirAccess.remove_absolute("user://test_tutorial.json")
	print("PASS: contextual tutorial success/failure, real rotation, camera, XP, triple, bonds, launch, resume, reset and Gym isolation")
	quit()
