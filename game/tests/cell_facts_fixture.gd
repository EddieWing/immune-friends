extends Node
# Controlled browser fixture: production simulation, save codec and cards.
# Run this scene explicitly; the game's normal entry point is unchanged.
const Save = preload("res://scripts/preparation_save.gd")
const Facts = preload("res://scripts/ui/cell_facts.gd")
var game
var chosen = 0
var appearance = 0
var status: Label
var cases = ["Swapper before", "Swapper after / unlinked", "Partner after / merged", "Survivor normal", "Survivor elite", "Greed in infection"]

func _ready():
	game = preload("res://main.tscn").instantiate()
	game.save_path = "user://cell_facts_fixture.json"
	game.settings_path = "user://cell_facts_fixture.cfg"
	add_child(game)
	game.settings.set_value("tutorial", "disabled", true)
	var layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var box = VBoxContainer.new()
	box.position = Vector2(1030, 110)
	box.custom_minimum_size.x = 360
	layer.add_child(box)
	status = Label.new()
	box.add_child(status)
	for caption in ["Next case", "HUD A / Classic / Gym", "Save + restore"]:
		var b = Button.new()
		b.text = caption
		b.custom_minimum_size.y = 44
		box.add_child(b)
		if caption == "Next case": b.pressed.connect(func(): chosen = (chosen + 1) % cases.size(); setup())
		elif caption == "Save + restore": b.pressed.connect(restore)
		else: b.pressed.connect(func(): appearance = (appearance + 1) % 3; present())
	setup()

func setup():
	game.sim.reset(42, 12)
	var s = game.sim
	s.blood.clear()
	s.blood_links.clear()
	var a = s.make_cell("swapper", Vector2.ZERO)
	var b = s.make_cell("greed_wall", Vector2(45, 0))
	a.max_hp = 9; a.hp = 9
	s.cells = [a, b]
	s.rebuild_links()
	if chosen in [1, 2]:
		s.phase = "recap"
		s.next_round()
		a.p = Vector2(-200, 0)
		s.rebuild_links()
		if chosen == 2:
			var copy = s.make_cell("greed_wall", b.p)
			s.cells.append(copy)
			s.merge(b, copy)
	if chosen in [3, 4]:
		a = s.make_cell("survivor_bomb", Vector2.ZERO)
		if chosen == 4: a.rank = 3
		s.cells = [a]
		for round_index in range(2):
			s.begin_battle()
			s.phase = "recap"
			s.next_round()
	if chosen == 5:
		a = s.make_cell("greed_wall", Vector2.ZERO)
		a.rank = 3
		s.cells = [a]
		s.money = 5
		s.begin_battle()
		a.hp -= 3
	game.selected = b if chosen == 2 else a
	game.paused = true
	game.modal.hide()
	game.menu_open = false
	game.main_menu.hide()
	game.hud_opacity = 1.0
	game.apply_menu_visibility()
	game.entering_game = false
	game.refresh()
	game.center_preparation_camera()
	present()

func present():
	game.ui_new = appearance == 0
	game.gym_mode = appearance == 2
	game.apply_appearance()
	game.inspected_cell = game.selected.id
	game.show_cell_card(game.selected.key, game.selected)
	status.text = "MC-069 | " + ["HUD A", "Classic", "Gym"][appearance] + "\n" + cases[chosen]

func restore():
	if game.sim.phase != "shop":
		status.text += "\nBattle is not a preparation checkpoint"
		return
	var id = game.selected.id
	var expected = Facts.lines(game.sim, game.selected)
	var encoded = JSON.stringify(Save.capture(game.sim))
	var checked = Save.inspect(JSON.parse_string(encoded), game.sim)
	assert(not checked.has("error"))
	Save.restore(game.sim, checked)
	game.selected = game.sim.cell_by_id(id)
	assert(Facts.lines(game.sim, game.selected) == expected)
	game.refresh()
	present()
	status.text += "\nJSON save/restore: PASS"
