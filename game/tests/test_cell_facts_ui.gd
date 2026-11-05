extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var fixture = preload("res://tests/cell_facts_fixture.tscn").instantiate()
	root.add_child(fixture)
	await process_frame
	var checks = 0
	for scenario in range(fixture.cases.size()):
		fixture.chosen = scenario
		fixture.setup()
		var game = fixture.game
		if scenario == 1:
			assert(game.selected.max_hp == 2)
			assert(game.selected.last_hp_swap.after == 2)
		if scenario == 2: assert(game.selected.max_hp == 11)
		if scenario in [3, 4]: assert(game.selected.radius_growth > 0)
		for appearance in range(3):
			fixture.appearance = appearance
			fixture.present()
			for frame in range(3): await process_frame
			var shown = game.hud_a.facts_text.text if appearance == 0 else game.detail.text
			if appearance == 0:
				assert(game.hud_a.facts_text.get_theme_font("normal_font").has_char(0x2192), "Swap history arrow must have a bundled glyph")
			else:
				assert(game.detail.get_theme_font("normal_font").has_char(0x2192))
				assert("Base HP" in shown and not "Health  [b]" in shown)
			for fact in game.cell_fact_lines(game.selected): assert(fact in shown)
			assert(game.hud_a.cell_block.visible if appearance == 0 else game.detail_panel.visible)
			if scenario != 5: fixture.restore()
			checks += 1
	fixture.queue_free()
	await process_frame
	print("PASS: %d actual card scenarios, HUD A / Classic / Gym, save restore" % checks)
	quit()
