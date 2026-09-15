extends Node2D
const Simulation = preload("res://scripts/simulation.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
var sim=Simulation.new()
var gym_mode=false
var gym_return={}
var gym_tool={}
var gym_setup={}
var lab_tools: Control
var ui: Control
var view: Node2D
var shop: HBoxContainer
var stats: Label
var phase_panel: PanelContainer
var incoming_tween: Tween
var detail: RichTextLabel
var incoming: RichTextLabel
var message: Label
var start_button: Button
var dock_play: Button
var freeze_button: Button
var xp_button: Button
var sell_button: Button
var modal: Control
var modal_panel: PanelContainer
var selected={}
var dragging=false
var rotating=false
var dragging_blood=-1
var panning=false
var pan_previous=Vector2.ZERO
var mouse_offset=Vector2.ZERO
var board_rect=Rect2(0,0,1440,900)
var last_phase=""
var menu_open=true
var main_menu: Control
var menu_tagline: Label
var menu_transition: Tween
var entering_game=false
var hud_opacity=1.0
var menu_time=0.0
var clock_accum=0.0
var visuals=preload("res://scripts/cell_visuals.gd").new()
var settings_path="user://settings.cfg"
var symbol_font: Font
var audio: AudioStreamPlayer
var ambient: AudioStreamPlayer
var bottom_panel: PanelContainer
var shop_toggle: Button
var auto_camera=true
var catalogue_key=""
var catalogue_text: RichTextLabel
var volumes=[0.45,0.3,0.6,0.3]
var settings=ConfigFile.new()
var save_path="user://run.json"
var detail_panel: PanelContainer
var detail_icon: TextureRect
var detail_key=""
var inspected_cell=-1
var inspected_virus={}
var detail_virus: Control
var term_panel: PanelContainer
var term_text: RichTextLabel
var income_panel: PanelContainer
var currency_panel: PanelContainer
var capacity_panel: PanelContainer
var round_label: Label
var refresh_button: Button
var shop_page=0
var previous_button: Button
var next_button: Button
var pending_offer={}
var shop_collapsed=false
var preview_wave=[]
var showing_recap=false
var results_pending=false
var results_delay=0.0
var results_stage=""
const RESULTS_PAUSE=1.25
const LAUNCH_SECONDS=0.9
var launch_remaining=0.0
var preview_sources=[]
var preview_center=Vector2.ZERO
var shade: ColorRect
var speed_buttons=[]
var playback_speed=1
var paused=false
var dock: Control
var dock_tween: Tween
var dock_open=true
var scanner: Control
var card_cell={}
var card_anchor=Vector2(720,780)
var zoom_target=0.88
var water_time=0.0
var background_material: ShaderMaterial
var zoom_gauge: Control
var auto_button: Button
const OfferButton=preload("res://scripts/ui/offer.gd")
const FieldDrop=preload("res://scripts/ui/field_drop.gd")
const CurrencyPips=preload("res://scripts/ui/currency.gd")
const XPRing=preload("res://scripts/ui/xp_ring.gd")

func _ready():
	DisplayServer.window_set_title("Microcosm • Immune Friends — Godot")
	make_theme()
	build_ui()
	audio=AudioStreamPlayer.new()
	add_child(audio)
	if settings.load(settings_path)==OK:
		for i in range(4): volumes[i]=settings.get_value("audio",str(i),volumes[i])
	if settings.has_section("graphics"):
		settings.erase_section("graphics")
		settings.save(settings_path)
	make_ambient()
	sim.reset(Time.get_ticks_usec()%100000,12)
	refresh()
	show_menu()
	var lab_layer=CanvasLayer.new()
	lab_layer.layer=20
	add_child(lab_layer)
	lab_tools=preload("res://scripts/ui/lab_tools.gd").new()
	lab_tools.game=self
	lab_layer.add_child(lab_tools)
	if "--smoke" in OS.get_cmdline_user_args():
		save_path="user://ui_smoke.json"
		modal.hide()
		menu_open=false
		sim.reset(42,12)
		for key in ["wall","seeker","orbiter","bodyguard","turret","bomb"]:
			var p=Vector2(140+(sim.cells.size()%3)*80,-130+(sim.cells.size()/3)*190)
			sim.cells.append(sim.make_cell(key,p))
		sim.tier=3
		sim.money=8
		sim.rebuild_links()
		refresh()

func make_theme():
	var theme=Theme.new()
	var ui_font=FontVariation.new()
	ui_font.base_font=ThemeDB.fallback_font
	ui_font.fallbacks=[preload("res://assets/fonts/NotoSansSymbols.ttf"),preload("res://assets/fonts/NotoSansSymbols2-Regular.ttf"),preload("res://assets/fonts/NotoSansMath-Regular.ttf")]
	symbol_font=ui_font
	theme.default_font_size=16
	theme.set_color("font_color","Label",Color("#354247"))
	theme.set_color("default_color","RichTextLabel",Color("#354247"))
	theme.set_color("font_color","Button",Color("#38454a"))
	theme.set_color("font_hover_color","Button",Color("#152c38"))
	theme.set_color("font_disabled_color","Button",Color("#a39e96"))
	theme.set_stylebox("normal","Button",style(Color("#f7f3e9"),8,Color("#c8c0b3")))
	theme.set_stylebox("hover","Button",style(Color("#fffaf0"),8,Color("#939f99")))
	theme.set_stylebox("pressed","Button",style(Color("#deddd0"),8,Color("#808e85")))
	theme.set_stylebox("disabled","Button",style(Color("#d7d1c6"),8,Color("#bdb7af")))
	theme.set_stylebox("focus","Button",style(Color(0,0,0,0),8,Color("#5b8177")))
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.theme=theme
	add_child(ui)

func style(color, radius=12, border=Color(0,0,0,0)):
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	s.border_color=border
	s.content_margin_left=12
	s.content_margin_right=12
	s.content_margin_top=9
	s.content_margin_bottom=9
	return s

func round_button(control, radius):
	for state in ["normal","hover","pressed","disabled","focus"]:
		var skin=control.get_theme_stylebox(state).duplicate()
		if skin is StyleBoxFlat: skin.set_corner_radius_all(radius)
		control.add_theme_stylebox_override(state,skin)

func panel(parent, rect, color=Color("#e6ddcb")):
	var p=PanelContainer.new()
	p.position=rect.position
	p.size=rect.size
	var skin=style(color,11,Color("#b3aa9b"))
	skin.shadow_color=Color(0.05,0.10,0.13,0.22)
	skin.shadow_size=4
	skin.shadow_offset=Vector2(2,4)
	p.add_theme_stylebox_override("panel",skin)
	parent.add_child(p)
	return p

func label(parent, text, pos, size_font=16, color=Color("#e7eee7")):
	var l=Label.new()
	l.text=text
	l.position=pos
	l.add_theme_font_size_override("font_size",size_font)
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l

func button(parent, text, action, min_size=Vector2(0,40)):
	var b=Button.new()
	b.text=text
	if text in ["⚙","⇈","⟳","❄","→","⌃","‹","›"]: b.add_theme_font_override("font",symbol_font)
	b.custom_minimum_size=min_size
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func fixed_icon_button(parent, glyph, action, dimensions, font_size):
	var b=preload("res://scripts/ui/icon_button.gd").new()
	b.glyph=glyph
	b.glyph_font=symbol_font
	b.glyph_size=font_size
	b.custom_minimum_size=dimensions
	b.size=dimensions
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func absolute_button(text, pos, size_button, action):
	var b=button(ui,text,action,size_button)
	b.position=pos
	b.size=size_button
	return b

func build_ui():
	var backdrop=TextureRect.new()
	background_material=ShaderMaterial.new()
	background_material.shader=preload("res://shaders/microscope.gdshader")
	backdrop.material=background_material
	backdrop.texture=preload("res://assets/art/microscope.png")
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.size=Vector2(1440,900)
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(backdrop)
	var field=FieldDrop.new()
	field.game=self
	field.position=board_rect.position
	field.size=board_rect.size
	field.clip_contents=true
	field.mouse_filter=Control.MOUSE_FILTER_PASS
	ui.add_child(field)
	view=ArenaView.new()
	view.position=Vector2(720,425)
	zoom_target=0.88
	view.scale=Vector2.ONE*zoom_target
	view.sim=sim
	view.visuals=visuals
	field.add_child(view)
	var vignette=ColorRect.new()
	vignette.name="MicroscopeVignette"
	vignette.size=Vector2(1440,900)
	vignette.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var lens_material=ShaderMaterial.new()
	lens_material.shader=preload("res://shaders/microscope_vignette.gdshader")
	vignette.material=lens_material
	ui.add_child(vignette)
	var gear=absolute_button("⚙",Vector2(24,12),Vector2(42,42),show_settings)
	gear.add_theme_font_size_override("font_size",30)
	gear.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	zoom_gauge=preload("res://scripts/ui/zoom_gauge.gd").new()
	zoom_gauge.game=self
	zoom_gauge.position=Vector2(1376,320)
	zoom_gauge.size=Vector2(40,260)
	ui.add_child(zoom_gauge)
	for value in [1,2,5,0]:
		var b=preload("res://scripts/ui/transport.gd").new()
		b.mode=value
		b.position=Vector2(598+speed_buttons.size()*62,12)
		b.custom_minimum_size=Vector2(54,42)
		b.size=Vector2(54,42)
		b.tooltip_text={1:"Play · normal speed",2:"Fast forward · ×2",5:"Fast forward · ×5",0:"Pause"}[value]
		b.pressed.connect(func():
			if value==0:
				paused=true
				update_transport()
			else:
				set_playback_speed(value)
				if sim.phase=="shop" and sim.reward_choices.is_empty(): start_battle())
		ui.add_child(b)
		speed_buttons.append(b)
	start_button=speed_buttons[0]
	set_playback_speed(1)
	scanner=preload("res://scripts/ui/scanner.gd").new()
	scanner.game=self
	scanner.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(scanner)
	phase_panel=panel(ui,Rect2(1270,-10,146,46),Color("#ed7865"))
	round_label=Label.new()
	round_label.add_theme_font_size_override("font_size",14)
	round_label.add_theme_color_override("font_color",Color("#fff7e7"))
	round_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	round_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	phase_panel.add_child(round_label)
	detail_panel=panel(ui,Rect2(194,85,340,0),Color("#d7edefef"))
	detail_panel.get_theme_stylebox("panel").border_color=Color("#efffff")
	var column=VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	detail_panel.add_child(column)
	detail_icon=TextureRect.new()
	detail_icon.custom_minimum_size=Vector2(300,98)
	detail_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(detail_icon)
	detail_virus=preload("res://scripts/ui/virus_preview.gd").new()
	detail_virus.custom_minimum_size=Vector2(300,98)
	column.add_child(detail_virus)
	detail_virus.hide()
	detail=RichTextLabel.new()
	detail.bbcode_enabled=true
	detail.custom_minimum_size=Vector2(310,0)
	detail.fit_content=true
	detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(detail)
	sell_button=button(column,"Sell",sell_selected,Vector2(0,32))
	detail_panel.hide()
	term_panel=panel(ui,Rect2(550,85,255,150))
	term_text=RichTextLabel.new()
	term_text.bbcode_enabled=true
	term_text.custom_minimum_size=Vector2(227,0)
	term_text.fit_content=true
	term_panel.add_child(term_text)
	term_panel.hide()
	income_panel=panel(ui,Rect2(-220,350,204,0),Color("#eb7b6a"))
	incoming=RichTextLabel.new()
	incoming.bbcode_enabled=true
	incoming.add_theme_font_override("normal_font",symbol_font)
	incoming.add_theme_font_override("bold_font",symbol_font)
	incoming.custom_minimum_size=Vector2(180,0)
	incoming.scroll_active=true
	income_panel.get_theme_stylebox("panel").content_margin_left=22
	income_panel.add_child(incoming)
	dock=Control.new()
	dock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(dock)
	currency_panel=panel(dock,Rect2(170,730,112,140))
	currency_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var pips=CurrencyPips.new()
	pips.game=self
	pips.custom_minimum_size=Vector2(112,140)
	currency_panel.add_child(pips)
	bottom_panel=panel(dock,Rect2(450,754,680,112),Color("#c5e2e63d"))
	var glass=bottom_panel.get_theme_stylebox("panel")
	glass.shadow_size=0
	glass.shadow_color=Color.TRANSPARENT
	glass.border_color=Color("#f1ffffc9")
	glass.border_width_top=2
	glass.border_width_bottom=2
	var contents=Control.new()
	contents.custom_minimum_size=Vector2(656,90)
	bottom_panel.add_child(contents)
	shop=HBoxContainer.new()
	shop.position=Vector2(28,-2)
	shop.size=Vector2(600,94)
	shop.alignment=BoxContainer.ALIGNMENT_CENTER
	shop.add_theme_constant_override("separation",4)
	contents.add_child(shop)
	previous_button=button(contents,"‹",func(): shop_page=maxi(0,shop_page-1); refresh(),Vector2(24,50))
	previous_button.position=Vector2(-4,20)
	next_button=button(contents,"›",func(): shop_page+=1; refresh(),Vector2(24,50))
	next_button.position=Vector2(636,20)
	capacity_panel=panel(dock,Rect2(350,834,88,32))
	capacity_panel.get_theme_stylebox("panel").content_margin_left=5
	capacity_panel.get_theme_stylebox("panel").content_margin_right=5
	capacity_panel.get_theme_stylebox("panel").content_margin_top=4
	capacity_panel.get_theme_stylebox("panel").content_margin_bottom=4
	stats=preload("res://scripts/ui/capacity.gd").new()
	stats.add_theme_constant_override("outline_size",0)
	stats.add_theme_font_size_override("font_size",14)
	stats.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	capacity_panel.add_child(stats)
	xp_button=fixed_icon_button(dock,"⇈",func(): sim.buy_xp(); changed(),Vector2(88,88),27)
	xp_button.position=Vector2(350,740)
	round_button(xp_button,44)
	var ring=XPRing.new()
	ring.game=self
	ring.position=Vector2(9,9)
	ring.size=Vector2(70,70)
	xp_button.add_child(ring)
	refresh_button=fixed_icon_button(dock,"⟳",func(): sim.roll_shop(); shop_page=0; changed(),Vector2(52,52),30)
	refresh_button.position=Vector2(1144,754)
	freeze_button=fixed_icon_button(dock,"❄",func(): sim.frozen=not sim.frozen; changed(),Vector2(52,52),27)
	freeze_button.position=Vector2(1144,814)
	round_button(refresh_button,26)
	round_button(freeze_button,26)
	dock_play=fixed_icon_button(dock,"▶",func(): set_playback_speed(1); start_battle(),Vector2(72,72),30)
	dock_play.position=Vector2(1210,774)
	dock_play.tooltip_text="Start infection phase"
	round_button(dock_play,36)
	shop_toggle=absolute_button("⌃",Vector2(175,850),Vector2(23,28),toggle_shop)
	shop_toggle.hide()
	message=label(dock,"",Vector2(450,727),13,Color("#233d4d"))
	message.size=Vector2(680,25)
	message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	modal=Control.new()
	modal.size=Vector2(1440,900)
	shade=ColorRect.new()
	shade.color=Color(0.04,0.07,0.10,0.58)
	shade.size=Vector2(1440,900)
	modal.add_child(shade)
	ui.add_child(modal)
	update_zoom()

func clear_modal(title, subtitle=""):
	catalogue_key=""
	showing_recap=false
	shade.color=Color(0.04,0.07,0.10,0.46)
	for child in modal.get_children():
		if child is PanelContainer: child.queue_free()
	modal_panel=panel(modal,Rect2(440,175,560,0))
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	modal_panel.add_child(col)
	var title_label=Label.new()
	title_label.text=title
	title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size",30)
	title_label.add_theme_color_override("font_color",Color("#42443e"))
	col.add_child(title_label)
	if subtitle!="":
		var sub=Label.new()
		sub.text=subtitle
		sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size=Vector2(0,0)
		sub.add_theme_color_override("font_color",Color("#65716f"))
		col.add_child(sub)
	modal.show()
	fit_modal.call_deferred(modal_panel)
	return col

func fit_modal(window):
	await get_tree().process_frame
	if not is_instance_valid(window): return
	window.size.y=window.get_combined_minimum_size().y
	window.position=(Vector2(1440,900)-window.size)*0.5
	if window.get_meta("field_report",false): window.position=Vector2(40,110)

func show_menu():
	if gym_mode:
		leave_gym()
		return
	if entering_game: return
	menu_open=true
	zoom_target=view.scale.x
	modal.hide()
	if main_menu: main_menu.queue_free()
	main_menu=Control.new()
	main_menu.size=Vector2(1440,900)
	main_menu.mouse_filter=Control.MOUSE_FILTER_STOP
	ui.add_child(main_menu)
	ui.move_child(modal,ui.get_child_count()-1)
	var title=label(main_menu,"MICROCOSM",Vector2(700,320),72,Color("#254b5c"))
	title.size=Vector2(680,100)
	menu_tagline=label(main_menu,"Tiny Cells Big Job",Vector2(825,550),27,Color("#416876"))
	var column=VBoxContainer.new()
	column.position=Vector2(150,280)
	column.size=Vector2(370,0)
	column.add_theme_constant_override("separation",14)
	main_menu.add_child(column)
	button(column,"Continue",func(): enter_microscope(func(): pass),Vector2(370,52))
	if FileAccess.file_exists(save_path):
		button(column,"Load saved preparation",func(): enter_microscope(load_run),Vector2(370,52))
	button(column,"New run · 12 rounds",func(): enter_microscope(func(): new_run(12)),Vector2(370,52))
	button(column,"Codex",show_codex,Vector2(370,52))
	button(column,"Gym",func(): enter_microscope(enter_gym),Vector2(370,52))
	button(column,"How to play",show_help,Vector2(370,52))
	button(column,"Quit",func(): save_run(); get_tree().quit(),Vector2(370,52))
	for control in column.get_children():
		control.alignment=HORIZONTAL_ALIGNMENT_LEFT
		control.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		control.add_theme_font_size_override("font_size",23)
	hud_opacity=0.0
	ui.get_node("MicroscopeVignette").material.set_shader_parameter("aperture",1.65)
	apply_menu_visibility()

func apply_menu_visibility():
	for child in ui.get_children():
		if child==ui.get_child(0) or child==main_menu or child==modal or child.name=="MicroscopeVignette": continue
		if child is CanvasItem: child.modulate.a=hud_opacity

func enter_microscope(action: Callable):
	if entering_game: return
	entering_game=true
	action.call()
	var tutorial=modal.visible
	modal.hide()
	menu_open=false
	var lens=ui.get_node("MicroscopeVignette").material
	menu_transition=create_tween().set_parallel(true)
	menu_transition.tween_property(main_menu,"modulate:a",0.0,0.75).set_trans(Tween.TRANS_SINE)
	menu_transition.tween_method(func(value): lens.set_shader_parameter("aperture",value),1.65,1.0,1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	menu_transition.tween_property(self,"hud_opacity",1.0,0.8).set_delay(0.45)
	menu_transition.chain().tween_callback(func():
		main_menu.hide()
		hud_opacity=1.0
		apply_menu_visibility()
		entering_game=false
		if tutorial: show_help())

func new_run(rounds):
	launch_remaining=0.0
	view.staging=""
	view.warning_wave=[]
	view.warning_sources=[]
	results_pending=false
	results_stage=""
	cancel_placement()
	shop_collapsed=false
	shop_page=0
	sim.reset(Time.get_ticks_usec()%100000,rounds)
	view.position=Vector2(720,425)
	view.scale=Vector2.ONE*0.88
	update_zoom()
	selected={}
	menu_open=false
	modal.hide()
	last_phase=""
	changed()
	if not settings.get_value("tutorial","disabled",false): show_help()

func show_help():
	var col=clear_modal("Take your time","Protect the red blood cells. Your team fights automatically.")
	var t=Label.new()
	t.text="1. Drag a cell from the shop onto the field for 2 protein.\n2. Or select an offer, then click on the field to place it.\n3. Hold and drag the round arrow to rotate a cell.\n4. Merge matching cells: the third creates an elite.\n5. Bonds automatically hold hands with nearby cells.\n6. Unspent protein disappear between waves.\n\nBomb hurts friendly cells too. Keep your team safe!"
	t.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size",16)
	col.add_child(t)
	button(col,"Got it",func(): modal.hide(); menu_open=false)

func show_settings():
	var col=clear_modal("Settings")
	modal_panel.position=Vector2(430,40)
	modal_panel.size=Vector2(580,0)
	col.add_theme_constant_override("separation",8)
	for i in range(4):
		var names=["Master volume","Music","Sound effects","Frequent sounds"]
		var l=Label.new()
		l.text=names[i]
		col.add_child(l)
		var slider=HSlider.new()
		slider.custom_minimum_size.y=24
		slider.min_value=0
		slider.max_value=1
		slider.step=0.05
		slider.value=volumes[i]
		var index=i
		slider.value_changed.connect(func(v): volumes[index]=v; settings.set_value("audio",str(index),v); settings.save(settings_path); ambient.volume_db=linear_to_db(maxf(0.0001,volumes[0]*volumes[1])))
		col.add_child(slider)
	var tutorial=CheckBox.new()
	tutorial.text="Skip tutorial when starting a run"
	tutorial.button_pressed=settings.get_value("tutorial","disabled",false)
	tutorial.toggled.connect(func(value): settings.set_value("tutorial","disabled",value); settings.save(settings_path))
	col.add_child(tutorial)
	button(col,"Toggle fullscreen",func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	var tutorials=HBoxContainer.new()
	col.add_child(tutorials)
	button(tutorials,"Reset tutorial",func(): settings.set_value("tutorial","disabled",false); settings.save(settings_path); show_help(),Vector2(272,40))
	button(tutorials,"Skip tutorial",func(): modal.hide(); menu_open=false,Vector2(272,38))
	var atlases=HBoxContainer.new()
	col.add_child(atlases)
	button(atlases,"Cell atlas",show_catalog,Vector2(272,40))
	button(atlases,"Virus atlas",show_virus_catalog,Vector2(272,40))
	button(col,"Main menu",show_menu)
	button(col,"Back",func(): modal.hide(); menu_open=false)

func enter_gym():
	if gym_mode: return
	cancel_placement()
	sim.release_blood()
	dragging=false
	rotating=false
	dragging_blood=-1
	gym_return={"sim":sim,"speed":playback_speed,"zoom":zoom_target,"position":view.position,"paused":paused,"auto":auto_camera}
	gym_mode=true
	sim=Simulation.new()
	sim.reset(4242,12)
	sim.gym_mode=true
	sim.wave=[]
	sim.offers=[]
	view.sim=sim
	view.blood_faces.states.clear()
	view.blood_faces.cursor=0
	view.blood_faces.phase=""
	view.staging=""
	view.warning_wave=[]
	view.warning_sources=[]
	view.position=Vector2(760,425)
	view.scale=Vector2.ONE*0.88
	zoom_target=0.88
	auto_camera=false
	paused=false
	set_playback_speed(1)
	gym_tool={}
	gym_setup={}
	selected={}
	results_pending=false
	results_stage=""
	launch_remaining=0.0
	clock_accum=0.0
	last_phase="shop"
	modal.hide()
	refresh()

func leave_gym():
	if not gym_mode: return
	cancel_placement()
	dragging=false
	rotating=false
	dragging_blood=-1
	sim=gym_return.sim
	view.sim=sim
	gym_mode=false
	gym_tool={}
	gym_setup={}
	selected={}
	view.selected_id=-1
	view.drag_preview=Vector2.INF
	view.blood_faces.states.clear()
	view.blood_faces.cursor=0
	view.blood_faces.phase=""
	view.position=gym_return.position
	zoom_target=gym_return.zoom
	view.scale=Vector2.ONE*zoom_target
	set_playback_speed(gym_return.speed)
	paused=gym_return.paused
	auto_camera=gym_return.auto
	last_phase=""
	clock_accum=0.0
	gym_return={}
	refresh()
	show_menu()

func gym_place(p):
	if gym_tool.is_empty() or (not gym_mode and not gym_tool.get("debug",false)) or sim.phase not in ["shop","battle"] or (sim.phase=="battle" and not paused): return
	var kind=gym_tool.kind
	if kind=="cell" and gym_tool.key=="__core":
		var id=0
		for b in sim.blood: id=maxi(id,b.id+1)
		var index=sim.blood.size()
		sim.blood.append({"id":id,"p":p,"alive":true})
		for i in range(index):
			if sim.blood[i].alive and sim.blood[i].p.distance_to(p)<28: sim.blood_links.append({"a":i,"b":index,"rest":26.0})
	elif kind=="cell":
		var c=sim.make_cell(gym_tool.key,p)
		c.rank=gym_tool.rank
		c.hp*=c.rank
		c.max_hp=c.hp
		sim.cells.append(c)
	elif kind=="source":
		var lane=sim.infection_sources.size()
		sim.infection_sources.append(p)
		var entry={"type":gym_tool.key,"count":gym_tool.count,"lane":lane}
		sim.wave.append(entry)
		if sim.phase=="battle":
			for i in range(entry.count): sim.spawn_queue.append({"type":entry.type,"lane":lane})
	elif kind=="virus":
		sim.spawn_virus({"type":gym_tool.key,"lane":0})
		var v=sim.viruses.back()
		v.p=p
		v.spawn_position=p
		v.exit=p
		v.emerging=false
	elif kind=="remove":
		var removed=false
		for c in sim.cells.duplicate():
			if sim.contains_cell(c,p,3):
				sim.cells.erase(c)
				removed=true
				break
		if not removed:
			for v in sim.viruses.duplicate():
				if v.p.distance_to(p)<18:
					sim.viruses.erase(v)
					removed=true
					break
		if not removed:
			for core in sim.blood:
				if core.alive and core.p.distance_to(p)<13:
					core.alive=false
					sim.record("blood_lost",{"id":core.id,"p":core.p})
					break
	if gym_tool.get("debug",false):
		gym_tool={}
		view.drag_preview=Vector2.INF
		lab_tools.debug_hint.text="Placed. Resume when ready."
	selected={}
	sim.rebuild_links()
	refresh()

func gym_run():
	if not gym_mode: return
	if lab_tools: lab_tools.hint.text="Test running. Pause to place objects; Reset setup to repeat."
	gym_tool={}
	view.drag_preview=Vector2.INF
	if sim.phase=="shop":
		gym_setup={"cells":sim.cells.duplicate(true),"blood":sim.blood.duplicate(true),"blood_links":sim.blood_links.duplicate(true),"viruses":sim.viruses.duplicate(true),"next_id":sim.next_id,"rng":sim.rng.state,"wave":sim.wave.duplicate(true),"sources":sim.infection_sources.duplicate()}
		var enemies=sim.viruses.duplicate(true)
		sim.begin_battle()
		sim.viruses=enemies
	paused=false
	clock_accum=0
	refresh()

func gym_reset_setup():
	if not gym_mode: return
	view.diagnostics.tracks.clear()
	if not gym_setup.is_empty():
		sim.cells=gym_setup.cells.duplicate(true)
		sim.blood=gym_setup.blood.duplicate(true)
		sim.blood_links=gym_setup.blood_links.duplicate(true)
		sim.viruses=gym_setup.viruses.duplicate(true)
		sim.next_id=gym_setup.next_id
		sim.rng.state=gym_setup.rng
		sim.wave=gym_setup.wave.duplicate(true)
		sim.infection_sources=gym_setup.sources.duplicate()
	sim.phase="shop"
	sim.elapsed=0
	sim.spawn_queue=[]
	sim.particles=[]
	sim.effects=[]
	sim.events=[]
	sim.blood_velocity={}
	sim.round_losses={"viruses":0,"core":0,"cells":0}
	paused=false
	selected={}
	gym_tool={}
	sim.rebuild_links()
	refresh()

func gym_clear():
	if not gym_mode: return
	gym_setup={}
	sim.cells=[]
	sim.viruses=[]
	sim.wave=[]
	gym_reset_setup()

func debug_replenish_core():
	if browsing_from_main_menu() or sim.phase not in ["shop","battle"]: return
	var restored=0
	for i in range(sim.blood.size()):
		if not sim.blood[i].alive:
			sim.blood[i].alive=true
			sim.blood_velocity.erase(i)
			restored+=1
	lab_tools.debug_hint.text="Restored %d lost core cells." % restored
	refresh()

func gym_restore_core():
	if not gym_mode: return
	paused=sim.phase=="battle"
	update_transport()
	var fresh=Simulation.new()
	fresh.reset(4242,12)
	sim.blood=fresh.blood.duplicate(true)
	sim.blood_links=fresh.blood_links.duplicate(true)
	sim.blood_velocity={}

func show_codex():
	var col=clear_modal("Codex","Discover the cells and viruses under the microscope.")
	button(col,"Cells · 27",show_catalog)
	button(col,"Viruses · 7",show_virus_catalog)
	button(col,"Back to main menu",func(): modal.hide())

func browsing_from_main_menu():
	return is_instance_valid(main_menu) and main_menu.visible

func show_catalog():
	var col=clear_modal("Cell atlas · 27 cells","Explore immune cells, their abilities and elite forms.")
	modal_panel.position=Vector2(250,95)
	modal_panel.size=Vector2(940,720)
	var split=HSplitContainer.new()
	split.custom_minimum_size=Vector2(880,480)
	split.size_flags_vertical=Control.SIZE_EXPAND_FILL
	col.add_child(split)
	var list=ItemList.new()
	list.custom_minimum_size=Vector2(310,470)
	list.fixed_icon_size=Vector2i(40,40)
	split.add_child(list)
	var text=RichTextLabel.new()
	catalogue_text=text
	text.bbcode_enabled=true
	text.custom_minimum_size=Vector2(520,470)
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(text)
	var keys=sim.catalog.keys()
	for key in keys:
		list.add_item(sim.catalog[key].name,cell_icon(key))
	list.item_selected.connect(func(index): catalogue_key=keys[index]; text.text=description(keys[index],false))
	list.select(0)
	catalogue_key=keys[0]
	text.text=description(keys[0],false)
	if browsing_from_main_menu(): button(col,"Back to Codex",show_codex)
	else: button(col,"Back to the field",func(): modal.hide(); menu_open=false)

func description(key, elite=false):
	var d=sim.catalog[key]
	var hp=d.hp*3 if elite else d.hp
	var r=d.range
	var interval=d.interval
	if elite:
		if key=="seeker": r=40
		if key=="bomb": r=20
		if key=="tag_dropper": interval=0.25
	var title=("Elite " if elite else "")+d.name
	var txt="[font_size=23][color=#34464c]"+title+"[/color][/font_size]\n"
	txt+="[color=#5b686a]"+d.category+"-cell  ·  "+("Reward" if d.tier==0 else "Level "+str(int(d.tier)))+"[/color]\n\n"
	txt+="Health  [b]"+str(hp)+"[/b]\n"
	if r>0: txt+="Range  [b]"+str(r)+"[/b]\n"
	if d.speed>0: txt+="Speed  [b]"+str(d.speed)+"[/b]\n"
	if interval>0: txt+="Interval  [b]"+str(interval)+" s[/b]\n"
	txt+="\n"+d.description+"\n\n[color=#847467]Space — view elite stats[/color]"
	if key=="accelerator": txt+="\n[color=#975535]Provisional ability: the original effect is not yet known.[/color]"
	return txt

func cell_icon(key):
	return visuals.icon(key,sim.catalog[key])

func refresh():
	stats.text="%d/%d " % [sim.cells.size(),sim.capacity()]
	stats.tooltip_text="Immune cells / capacity"
	phase_panel.visible=not gym_mode and sim.phase!="battle"
	round_label.text="Round %d / %d" % [mini(sim.round_no+1,sim.target_rounds) if sim.phase=="recap" and results_stage=="forecast" else sim.round_no,sim.target_rounds]
	var display_wave=preview_wave if sim.phase=="recap" and not preview_wave.is_empty() else sim.wave
	incoming.text="[color=#fff6df][b]Incoming infection[/b][/color]\n"
	for lane in range(3):
		var items=display_wave.filter(func(e): return e.lane==lane)
		if items.is_empty(): continue
		incoming.text+="\n[color=#663e4a]Lane "+str(lane+1)+"[/color]\n"
		for entry in items:
			incoming.text+="[color=#fff7e7]"+virus_glyph(entry.type)+" ×"+str(entry.count)+"[/color]\n"
	layout_incoming.call_deferred()
	var is_shop=sim.phase=="shop"
	animate_dock(is_shop and not shop_collapsed and not gym_mode)
	shop_toggle.hide()
	update_transport()
	if not is_shop:
		detail_panel.hide()
		term_panel.hide()
	elif not selected.is_empty() and sim.cells.has(selected) and selected.id==inspected_cell:
		show_cell_card(selected.key,selected)
	elif pending_offer.is_empty():
		detail_panel.hide()
		term_panel.hide()
	if selected.is_empty() or not sim.cells.has(selected):
		selected={}
		view.selected_id=-1
	else:
		view.selected_id=selected.id
	sell_button.disabled=selected.is_empty() or not is_shop
	dock_play.disabled=not is_shop or not sim.reward_choices.is_empty()
	start_button.disabled=launch_remaining>0 or sim.phase not in ["shop","battle"] or not sim.reward_choices.is_empty()
	xp_button.disabled=sim.money<3 or sim.tier>=4 or not is_shop
	xp_button.tooltip_text="Level %d · XP %d\nBuy XP · 3 protein" % [sim.tier,sim.xp]
	refresh_button.disabled=sim.money<1 or not is_shop
	refresh_button.tooltip_text="Refresh offers · 1 protein"
	freeze_button.disabled=not is_shop
	freeze_button.set("glyph","❄" if not sim.frozen else "❄▣")
	freeze_button.queue_redraw()
	freeze_button.tooltip_text="Shop frozen. Click to unfreeze." if sim.frozen else "Keep offers for the next round · free"
	if not inspected_virus.is_empty() and inspected_virus.get("alive",false) and sim.viruses.has(inspected_virus):
		show_field_virus(inspected_virus)
	message.visible=is_shop
	message.text=sim.last_message
	var entries=[]
	for i in range(sim.offers.size()): entries.append({"key":sim.offers[i],"index":i,"reward":false})
	for i in range(sim.rewards.size()): entries.append({"key":sim.rewards[i],"index":i,"reward":true})
	var pages=maxi(1,int(ceil(entries.size()/6.0)))
	shop_page=clampi(shop_page,0,pages-1)
	for child in shop.get_children():
		shop.remove_child(child)
		child.queue_free()
	for n in range(shop_page*6,mini(entries.size(),shop_page*6+6)):
		var entry=entries[n]
		add_offer(entry.key,entry.index,entry.reward)
	previous_button.visible=pages>1
	next_button.visible=pages>1
	previous_button.disabled=shop_page==0
	next_button.disabled=shop_page==pages-1
	if not gym_mode and not sim.reward_choices.is_empty() and not modal.visible: show_reward()

func add_offer(key,index,reward):
	var d=sim.catalog[key]
	var card=OfferButton.new()
	card.game=self
	card.key=key
	card.index=index
	card.reward=reward
	card.category=d.category
	card.icon_texture=cell_icon(key)
	card.custom_minimum_size=Vector2(96,94)
	card.tooltip_text=d.name
	card.disabled=sim.phase!="shop"
	for c in sim.cells:
		if c.key==key and c.rank==2: card.elite_ready=true
	card.pressed.connect(func(): arm_offer(index,reward))
	card.mouse_entered.connect(func():
		beep(510,0.025,true)
		show_cell_card(key))
	card.mouse_exited.connect(func():
		if not selected.is_empty() and selected.id==inspected_cell: show_cell_card(selected.key,selected)
		elif pending_offer.is_empty():
			detail_panel.hide()
			term_panel.hide())
	shop.add_child(card)

func buy_offer(index,reward):
	var p=Vector2(180+(sim.cells.size()%4)*62,160+(sim.cells.size()/4)*49)
	if not selected.is_empty(): p=selected.p+Vector2(46,0)
	buy_offer_at(index,reward,p)

func sell_selected():
	if selected.is_empty(): return
	sim.sell(selected)
	selected={}
	changed()

func show_reward():
	var col=clear_modal("Elite cell!","Choose a reward. Collect it from the shop for free.")
	modal_panel.position=Vector2(355,156)
	modal_panel.size=Vector2(730,530)
	var choices=sim.reward_choices[0]
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	col.add_child(row)
	for i in range(2):
		var key=choices[i]
		var index=i
		var choice=VBoxContainer.new()
		choice.custom_minimum_size=Vector2(335,350)
		row.add_child(choice)
		var picture=TextureRect.new()
		picture.texture=cell_icon(key)
		picture.custom_minimum_size=Vector2(335,105)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		choice.add_child(picture)
		var text=RichTextLabel.new()
		text.bbcode_enabled=true
		text.text=description(key)
		text.custom_minimum_size=Vector2(335,220)
		choice.add_child(text)
		button(choice,"Choose",func():
			sim.choose_reward(index)
			modal.hide()
			shop_page=int(floor((sim.offers.size()+sim.rewards.size()-1)/6.0))
			changed(),Vector2(335,40))

func start_battle():
	if gym_mode:
		gym_run()
		return
	if sim.phase!="shop" or not sim.reward_choices.is_empty() or launch_remaining>0: return
	paused=false
	sim.release_blood()
	cancel_placement()
	save_run()
	sim.begin_battle()
	launch_remaining=LAUNCH_SECONDS
	view.staging="launch"
	beep(420,0.16)
	dragging=false
	rotating=false
	refresh()

func changed():
	sim.rebuild_links()
	refresh()
	save_run()

func _process(delta):
	menu_time+=delta
	if is_instance_valid(main_menu) and main_menu.visible:
		menu_tagline.position=Vector2(825+sin(menu_time*0.37)*35,550+sin(menu_time*0.65)*18)
		apply_menu_visibility()
		if not entering_game:
			advance_camera(delta)
			return
	elif hud_opacity<1.0:
		hud_opacity=1.0
		apply_menu_visibility()
	position_scanner()
	advance_camera(delta)
	if not entering_game: advance_simulation(delta)
	if sim.phase!=last_phase:
		last_phase=sim.phase
		refresh()
		if sim.phase in ["recap","win","lose"]:
			results_pending=true
			results_delay=RESULTS_PAUSE
			results_stage="settling"
			view.staging="aftermath"
			modal.hide()
	advance_results(delta)
	if not modal.visible:
		var movement=Vector2(float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D)),float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S)))
		view.position+=movement*delta*280
	if sim.phase=="battle":
		stats.text="%d/%d " % [sim.cells.size(),sim.capacity()]
		if auto_camera and not panning:
			var focus=Vector2.ZERO
			var count=0
			for b in sim.blood:
				if b.alive: focus+=b.p; count+=1
			if count>0: focus/=count
			view.position=view.position.lerp(Vector2(720,425)-focus*view.scale.x,delta*1.2)

func _input(event):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		sim.release_blood()
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_F3:
			lab_tools.debug_panel.visible=not lab_tools.debug_panel.visible
			get_viewport().set_input_as_handled()
			return
		if event.keycode==KEY_ESCAPE:
			if gym_mode or not gym_tool.is_empty():
				gym_tool={}
				if lab_tools: lab_tools.hint.text="Placement cancelled. Choose an object to place, or run the test."
				view.drag_preview=Vector2.INF
				get_viewport().set_input_as_handled()
				return
			if launch_remaining>0: return
			if is_instance_valid(main_menu) and main_menu.visible:
				if modal.visible: modal.hide()
				elif not entering_game: enter_microscope(func(): pass)
				get_viewport().set_input_as_handled()
				return
			get_viewport().set_input_as_handled()
			if not pending_offer.is_empty():
				cancel_placement()
				refresh()
				return
			if sim.phase in ["recap","win","lose"] or not sim.reward_choices.is_empty(): return
			if modal.visible: modal.hide(); menu_open=false
			else: show_menu()
		if event.keycode==KEY_SPACE:
			get_viewport().set_input_as_handled()
			if modal.visible and catalogue_key!="" and is_instance_valid(catalogue_text):
				catalogue_text.text=description(catalogue_key,true)
			elif detail_key!="" and detail_panel.visible: detail.text=description(detail_key,true)

func _unhandled_input(event):
	if modal.visible or launch_remaining>0: return
	if event is InputEventMouseButton:
		var screen=event.position
		if event.button_index==MOUSE_BUTTON_RIGHT:
			panning=event.pressed and board_rect.has_point(screen)
			pan_previous=screen
		if not board_rect.has_point(screen) and event.pressed: return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var factor=1.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.1
			set_zoom(zoom_target*factor)
		if event.button_index==MOUSE_BUTTON_LEFT:
			var world=view.get_global_transform().affine_inverse()*screen
			if event.pressed:
				if not gym_tool.is_empty():
					gym_place(world)
					return
				if not pending_offer.is_empty() and sim.phase=="shop":
					buy_offer_at(pending_offer.index,pending_offer.reward,world)
					return
				if sim.phase=="shop" and not selected.is_empty():
					var handle=selected.p+Vector2.RIGHT.rotated(selected.angle)*62
					if world.distance_to(handle)<14:
						rotating=true
						return
				inspected_virus={}
				inspected_cell=-1
				detail_panel.hide()
				term_panel.hide()
				selected={}
				for c in sim.cells:
					if c.alive and sim.contains_cell(c,world,6):
						selected=c
				if not selected.is_empty():
					if event.double_click: inspected_cell=selected.id
					dragging=sim.phase=="shop"
					mouse_offset=selected.p-world
				elif sim.phase=="shop":
					for i in range(sim.blood.size()):
						if sim.blood[i].alive and sim.blood[i].p.distance_to(world)<16:
							dragging_blood=i
							break
				if selected.is_empty() and event.double_click:
					for virus in sim.viruses:
						if virus.alive and virus.p.distance_to(world)<20:
							inspected_virus=virus
							break
				refresh()
			else:
				if dragging and not selected.is_empty() and not gym_mode:
					for c in sim.cells.duplicate():
						if c.id!=selected.id and c.p.distance_to(selected.p)<35 and sim.compatible(c,selected):
							if sim.merge(c,selected): selected=c; break
					changed()
				if rotating or dragging_blood>=0: changed()
				dragging=false
				rotating=false
				dragging_blood=-1
	if event is InputEventMouseMotion:
		var world=view.get_global_transform().affine_inverse()*event.position
		if not pending_offer.is_empty() or not gym_tool.is_empty(): view.drag_preview=world
		if panning:
			view.position+=event.position-pan_previous
			pan_previous=event.position
		if rotating and not selected.is_empty():
			selected.angle=(world-selected.p).angle()
		elif dragging and not selected.is_empty():
			selected.p=(world+mouse_offset).clamp(Vector2(-590,-345),Vector2(590,325))
			sim.rebuild_links()
		elif dragging_blood>=0:
			sim.move_blood(dragging_blood,world)

func save_run():
	if gym_mode: return
	if sim.phase!="shop": return
	var cell_data=[]
	for c in sim.cells:
		var item=c.duplicate()
		item.p=[c.p.x,c.p.y]
		item.start=[c.p.x,c.p.y]
		cell_data.append(item)
	var blood_data=[]
	for b in sim.blood: blood_data.append({"p":[b.p.x,b.p.y],"alive":b.alive,"id":b.id})
	var data={"version":1,"seed":sim.seed_value,"round":sim.round_no,"rounds":sim.target_rounds,
		"money":sim.money,"tier":sim.tier,"xp":sim.xp,"frozen":sim.frozen,"next_id":sim.next_id,
		"cells":cell_data,"blood":blood_data,"blood_links":sim.blood_links,"offers":sim.offers,"rewards":sim.rewards,
		"choices":sim.reward_choices,"rng_state":str(sim.rng.state),
		"infection_sources":sim.infection_sources.map(func(p): return [p.x,p.y]),
		"source_center":[sim.source_center.x,sim.source_center.y]}
	var file=FileAccess.open(save_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(data))

func load_run():
	launch_remaining=0.0
	view.staging=""
	view.warning_wave=[]
	view.warning_sources=[]
	var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or data.get("version",0)!=1:
		sim.last_message="Could not read the saved game."
		return
	sim.reset(int(data.seed),int(data.rounds))
	sim.round_no=int(data.round)
	sim.money=int(data.money)
	sim.tier=int(data.tier)
	sim.xp=int(data.xp)
	sim.frozen=data.frozen
	sim.next_id=int(data.next_id)
	sim.cells=data.cells
	for c in sim.cells:
		c.p=Vector2(c.p[0],c.p[1])
		c.start=c.p
	sim.blood=data.blood
	for b in sim.blood: b.p=Vector2(b.p[0],b.p[1])
	if data.has("blood_links"): sim.blood_links=data.blood_links
	else: sim.rebuild_blood_links()
	sim.offers=data.offers
	sim.rewards=data.rewards
	sim.reward_choices=data.choices
	sim.rng.state=int(data.rng_state)
	sim.make_wave()
	if data.has("infection_sources") and data.has("source_center"):
		sim.infection_sources=data.infection_sources.map(func(p): return Vector2(p[0],p[1]))
		sim.source_center=Vector2(data.source_center[0],data.source_center[1])
	sim.rebuild_links()
	selected={}
	modal.hide()
	menu_open=false
	last_phase=""
	refresh()

func beep(frequency,length,frequent=false):
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	var buffer=PackedByteArray()
	buffer.resize(int(length*22050)*2)
	for i in range(buffer.size()/2):
		var sample=sin(i*frequency*TAU/22050)*0.12*(1-float(i)/(buffer.size()/2))
		buffer.encode_s16(i*2,int(sample*32767))
	stream.data=buffer
	audio.stream=stream
	audio.volume_db=linear_to_db(maxf(0.0001,volumes[0]*volumes[3 if frequent else 2]))
	if DisplayServer.get_name()!="headless": audio.play()

func make_ambient():
	ambient=AudioStreamPlayer.new()
	add_child(ambient)
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=22050*8
	var buffer=PackedByteArray()
	buffer.resize(stream.loop_end*2)
	for i in range(stream.loop_end):
		var t=float(i)/22050.0
		var sample=(sin(t*110*TAU)*0.035+sin(t*165*TAU)*0.022+sin(t*220*TAU)*0.013)*(0.7+0.3*sin(t*TAU/8))
		buffer.encode_s16(i*2,int(sample*32767))
	stream.data=buffer
	ambient.stream=stream
	ambient.volume_db=linear_to_db(maxf(0.0001,volumes[0]*volumes[1]))
	if DisplayServer.get_name()!="headless": ambient.play()





func buy_offer_at(index,reward,p):
	var id_before=sim.next_id
	if sim.purchase(index,p.clamp(Vector2(-590,-345),Vector2(590,325)),reward):
		selected={}
		for c in sim.cells:
			if c.id==id_before: selected=c
		beep(630,0.08)
	else: beep(190,0.07)
	cancel_placement()
	changed()

func arm_offer(index,reward):
	var source=sim.rewards if reward else sim.offers
	if index<0 or index>=source.size(): return
	pending_offer={"index":index,"reward":reward,"key":source[index]}
	show_cell_card(source[index])
	sim.last_message="Drag onto the field or click to place. Esc to cancel."
	message.text=sim.last_message

func cancel_placement():
	pending_offer={}
	if view: view.drag_preview=Vector2.INF

func toggle_shop():
	shop_collapsed=not shop_collapsed
	refresh()

func set_zoom(value):
	if browsing_from_main_menu() or entering_game: return
	zoom_target=clampf(value,0.45,1.5)
	update_zoom()

func advance_camera(delta):
	var value=lerpf(view.scale.x,zoom_target,1.0-exp(-delta/0.065))
	if absf(value-zoom_target)<0.0001: value=zoom_target
	view.scale=Vector2.ONE*value
	water_time+=delta
	background_material.set_shader_parameter("camera_zoom",value)
	background_material.set_shader_parameter("flow_time",water_time)
	update_zoom()

func update_zoom():
	if zoom_gauge: zoom_gauge.queue_redraw()
	if auto_button: auto_button.modulate=Color.WHITE if auto_camera else Color("#95a5ab")

func set_playback_speed(value):
	if value not in [1,2,5]: return
	paused=false
	playback_speed=value
	view.playback_speed=value
	update_transport()

func update_transport():
	for b in speed_buttons:
		b.active=(b.mode==0 if paused else b.mode==playback_speed)
		b.disabled=launch_remaining>0 or sim.phase not in ["shop","battle"] or (sim.phase=="shop" and (b.mode==0 or not sim.reward_choices.is_empty()))
		b.queue_redraw()

func animate_dock(open):
	if dock_open==open: return
	dock_open=open
	if dock_tween: dock_tween.kill()
	dock.show()
	dock_tween=create_tween()
	dock_tween.tween_property(dock,"position:y",0.0 if open else 180.0,0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not open: dock_tween.tween_callback(dock.hide)

func position_scanner():
	if not inspected_virus.is_empty() and (not inspected_virus.get("alive",false) or not sim.viruses.has(inspected_virus)):
		inspected_virus={}
		detail_panel.hide()
	if not scanner or not detail_panel.visible: return
	var anchor=card_anchor
	if not inspected_virus.is_empty(): anchor=view.to_global(inspected_virus.p)
	if not card_cell.is_empty() and sim.cells.has(card_cell):
		anchor=view.to_global(card_cell.p)
	var right=anchor.x<720
	var x=anchor.x+65 if right else anchor.x-65-detail_panel.size.x
	detail_panel.position=Vector2(clampf(x,216,1350-detail_panel.size.x),clampf(anchor.y-detail_panel.size.y*0.5,70,maxf(70,710-detail_panel.size.y)))
	term_panel.hide()
	scanner.anchor=anchor
	scanner.queue_redraw()

func advance_simulation(delta):
	if launch_remaining>0:
		launch_remaining=maxf(0,launch_remaining-delta)
		if launch_remaining==0:
			view.staging=""
			update_transport()
		return
	if paused and sim.phase=="battle": return
	if sim.phase=="battle":
		clock_accum+=minf(delta,0.1)*playback_speed
		while clock_accum+0.0000001>=1.0/60.0 and sim.phase=="battle":
			sim.update(1.0/60.0)
			clock_accum=maxf(0,clock_accum-1.0/60.0)
		if sim.phase!="battle": clock_accum=0.0
	else:
		clock_accum=0.0
		sim.update(delta)

func show_cell_card(key,c={}):
	detail_icon.show()
	detail_virus.hide()
	if sim.phase!="shop": return
	detail_key=key
	card_cell=c
	card_anchor=get_viewport().get_mouse_position()
	detail_panel.show()
	detail_icon.texture=cell_icon(key)
	detail_panel.size.y=0
	term_panel.size.y=0
	detail.text=description(key,c.get("rank",1)==3)
	sell_button.visible=not c.is_empty()
	if not c.is_empty():
		detail.text+="\n[b]Current: "+str(snappedf(c.hp,0.1))+" HP  ·  "+str(c.rank)+"/3[/b]"
		sell_button.text="Sell · "+str(c.sale)
	var behavior=sim.catalog[key].behavior
	term_panel.show()
	var term="B-Cell" if sim.catalog[key].category=="B" else "T-Cell"
	var explanation="An immune cell category. Contributes to Resonant Wall and Cannon bonuses." if term=="B-Cell" else "An immune cell category. Tags increase its virus detection range."
	if behavior=="bond":
		term="Bonds / Connected"
		explanation="Physical links to nearby immune cells. Connected means the entire network joined by bonds."
	elif key in ["tag_dropper","tag_sprayer"]:
		term="Tag Protein"
		explanation="Stops a virus for 1 second and doubles the range at which T-cells detect it."
	elif key in ["generator","zapper"]:
		term="Electric Charge"
		explanation="Electricity travels through immune cells, proteins and viruses."
	term_text.text="[b]"+term+"[/b]\n"+explanation
	detail.text+="\n\n[color=#537a83][b]"+term+"[/b] · "+explanation+"[/color]"
	position_scanner.call_deferred()

func show_field_virus(virus):
	inspected_virus=virus
	card_cell={}
	detail_key=""
	detail_icon.hide()
	detail_virus.kind=virus.type
	detail_virus.show()
	detail.text="[b]"+virus.type.capitalize()+" Virus[/b]\n\n"+virus_description(virus.type)+"\n\nCurrent HP: "+str(snappedf(virus.hp,0.1))
	sell_button.hide()
	term_panel.hide()
	detail_panel.show()
	detail_panel.size.y=0
	position_scanner.call_deferred()

func virus_glyph(key):
	return {"basic":"✹","wave":"≈","jumper":"↟","hungry":"●","swarmer":"✣","seeker":"♟","avoider":"◇"}.get(key,"●")

func advance_results(delta):
	if not results_pending: return
	# Damage has stopped; only transient visuals finish before the results pause.
	for particle in sim.particles:
		particle.life-=delta
		particle.p+=particle.v*delta
	sim.particles=sim.particles.filter(func(p): return p.life>0 and p.kind=="bullet")
	if not sim.effects.is_empty() or not sim.particles.is_empty(): return
	results_delay-=delta
	if results_delay>0: return
	results_pending=false
	show_infection_results()

func show_infection_results():
	results_stage="losses"
	var losses=sim.round_losses
	var text="Viral cells destroyed: %d" % losses.viruses
	if losses.core>0: text+="\nCore cells lost: %d" % losses.core
	text+="\nImmune cells lost: %d" % losses.cells
	if sim.phase=="recap": text+="\n\nNext preparation budget: %d protein\nAvailable when preparation begins." % mini(sim.round_no+4,10)
	if not sim.rewards.is_empty(): text+="\nFree cells available: %d" % sim.rewards.size()
	var col=clear_modal("Infection phase complete",text)
	modal_panel.set_meta("field_report",true)
	modal_panel.size.x=430
	shade.color=Color(0,0,0,0)
	button(col,"OK",func():
		if sim.phase=="recap": show_recap()
		else: show_run_result())

func show_run_result():
	results_stage="finished"
	var col=clear_modal("Defense successful!" if sim.phase=="win" else "No core cells left","You survived %d rounds." % sim.round_no)
	button(col,"New run",func():new_run(sim.target_rounds))
	button(col,"Main menu",show_menu)

func show_recap():
	results_stage="forecast"
	var next_sim=Simulation.new()
	next_sim.reset(sim.seed_value,sim.target_rounds)
	next_sim.round_no=sim.round_no+1
	next_sim.blood=sim.blood.duplicate(true)
	next_sim.make_wave()
	preview_wave=next_sim.wave.duplicate(true)
	preview_sources=next_sim.infection_sources.duplicate()
	preview_center=next_sim.source_center
	view.warning_wave=preview_wave
	view.warning_sources=preview_sources
	view.staging="warning"
	view.warning_time=0.0
	var changes=""
	for lane in range(3):
		var types=[]
		for entry in sim.wave+preview_wave:
			if entry.lane==lane and entry.type not in types: types.append(entry.type)
		for type in types:
			var before=0
			var after=0
			for entry in sim.wave:
				if entry.lane==lane and entry.type==type: before+=entry.count
			for entry in preview_wave:
				if entry.lane==lane and entry.type==type: after+=entry.count
			if before!=after:
				changes+="Lane %d · %s: %d to %d%s\n" % [lane+1,type.capitalize(),before,after," (new)" if before==0 else ""]
	if changes.is_empty(): changes="The infection lineup is unchanged.\n"
	var kinds=[]
	for entry in preview_wave:
		if entry.type not in kinds: kinds.append(entry.type)
	for kind in kinds:
		changes+="\n"+kind.capitalize()+": "+wave_trait(kind)+"\n"
	changes+="\nPreparation protein: %d" % mini(sim.round_no+4,10)
	var col=clear_modal("Incoming infection · %d" % (sim.round_no+1),changes)
	modal_panel.set_meta("field_report",true)
	modal_panel.size.x=440
	showing_recap=true
	shade.color=Color(0,0,0,0)
	button(col,"OK",advance_recap)
	refresh()

func advance_recap():
	results_stage=""
	if sim.phase!="recap": return
	sim.next_round()
	if not preview_sources.is_empty():
		sim.infection_sources=preview_sources.duplicate()
		sim.source_center=preview_center
	view.warning_wave=[]
	view.warning_sources=[]
	view.staging=""
	preview_sources=[]
	preview_wave=[]
	showing_recap=false
	shop_page=0
	modal.hide()
	menu_open=false
	changed()

func wave_trait(kind):
	return {"basic":"Heads toward core cells.","wave":"Weaves while approaching.","jumper":"Leaps forward; invulnerable during the leap.","hungry":"Consumes virus protein to gain health.","swarmer":"Groups with nearby viruses.","seeker":"Can divert toward immune cells.","avoider":"Avoids nearby immune cells."}.get(kind,"")

func virus_description(key):
	return {
		"basic":"A basic virus that approaches blood cells.",
		"wave":"Health: 1\nMoves along a wave-shaped path.",
		"jumper":"Moves slowly, then leaps forward. Invulnerable while jumping.",
		"hungry":"Absorbs Virus Protein to gain health.",
		"swarmer":"Health: 1\nAttracted to other viruses and attaches to them.",
		"seeker":"Health: 2\nSeeks immune cells within range.",
		"avoider":"Health: 1\nAvoids nearby immune cells."
	}.get(key,"")

func show_virus_catalog():
	var col=clear_modal("Virus atlas · 7 viruses","Meet the invaders emerging from infection sources.")
	modal_panel.size=Vector2(940,0)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	col.add_child(row)
	var list=ItemList.new()
	list.custom_minimum_size=Vector2(280,420)
	row.add_child(list)
	var info=VBoxContainer.new()
	info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var preview=preload("res://scripts/ui/virus_preview.gd").new()
	preview.custom_minimum_size=Vector2(0,150)
	info.add_child(preview)
	var facts=RichTextLabel.new()
	facts.bbcode_enabled=true
	facts.custom_minimum_size=Vector2(540,240)
	info.add_child(facts)
	var keys=["basic","wave","jumper","hungry","swarmer","seeker","avoider"]
	var select=func(index):
		var key=keys[index]
		preview.kind=key
		facts.text="[font_size=26]"+key.capitalize()+" Virus[/font_size]\n\n"+virus_description(key)+"\n\n[color=#65716f]Infection sources release viruses into the field. Protect your red blood cells.[/color]"
	for key in keys: list.add_item(key.capitalize()+" Virus")
	list.item_selected.connect(select)
	list.select(0)
	select.call(0)
	button(col,"Back to Codex" if browsing_from_main_menu() else "Back",show_codex if browsing_from_main_menu() else show_settings)

func layout_incoming():
	await get_tree().process_frame
	if not is_instance_valid(incoming): return
	incoming.custom_minimum_size.y=clampf(incoming.get_content_height(),44,580)
	income_panel.size.y=incoming.custom_minimum_size.y+18
	income_panel.position.y=(900-income_panel.size.y)*0.5
	var show_panel=sim.phase=="shop" and not gym_mode
	var destination=-8.0 if show_panel else -220.0
	if incoming_tween and incoming_tween.is_running(): incoming_tween.kill()
	if show_panel: income_panel.show()
	if is_equal_approx(income_panel.position.x,destination):
		income_panel.visible=show_panel
		return
	incoming_tween=create_tween()
	incoming_tween.tween_property(income_panel,"position:x",destination,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not show_panel: incoming_tween.tween_callback(income_panel.hide)
