extends SceneTree
var failures=0
func check(ok,message):
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func _initialize():
	call_deferred("run")
func run():
	var scene=load("res://main.tscn").instantiate()
	scene.save_path="user://test_roundtrip.json"
	root.add_child(scene)
	await process_frame
	var symbols_ok=true
	for symbol in "⚙⇈⟳❄→⌃⌄♟ⓘ✹≈↟●✣◇▣":
		var covered=false
		for font in scene.symbol_font.fallbacks:
			covered=covered or font.has_char(symbol.unicode_at(0))
		symbols_ok=symbols_ok and covered
	check(symbols_ok,"bundled fonts cover every UI icon without OS fonts")
	scene.sim.reset(42,12)
	scene.modal.hide()
	scene.buy_offer(0,false)
	var c=scene.sim.cells[0]
	c.p=Vector2(321,-87)
	c.angle=1.25
	scene.sim.frozen=true
	var money=scene.sim.money
	var saved_sources=scene.sim.infection_sources.duplicate()
	scene.save_run()
	scene.sim.reset(77,10)
	scene.load_run()
	check(scene.sim.infection_sources==saved_sources,"save restores infection sources despite moved core cells")
	check(scene.sim.cells.size()==1,"UI purchase saved")
	check(scene.sim.cells[0].p==Vector2(321,-87) and scene.sim.cells[0].angle==1.25,"position and rotation roundtrip")
	check(scene.sim.money==money and scene.sim.frozen,"economy and freeze roundtrip")
	check(scene.sim.target_rounds==12 and scene.sim.seed_value==42,"run configuration restored")
	scene.show_catalog()
	await process_frame
	check(scene.modal.visible,"catalogue opens")
	var normal_description=scene.catalogue_text.text
	var key=InputEventKey.new()
	key.keycode=KEY_SPACE
	key.pressed=true
	scene._input(key)
	check(scene.catalogue_text.text==normal_description and not "Space" in normal_description,"Space does not switch elite preview and its hint is removed")
	scene.modal.hide()
	scene.show_settings()
	await process_frame
	check(scene.modal.visible,"settings opens")
	scene.modal.hide()
	scene.start_battle()
	check(scene.sim.phase=="battle","UI starts battle")
	# The saved state remains preparation, not a partially resolved fight.
	scene.load_run()
	check(scene.sim.phase=="shop" and scene.sim.cells[0].alive,"load restores prebattle checkpoint")
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test_roundtrip.json")
	print("RESULT: 10 checks, %d failures" % failures)
	quit(1 if failures else 0)
