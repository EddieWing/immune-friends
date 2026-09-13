extends Node2D
const Simulation = preload("res://scripts/simulation.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
var sim=Simulation.new()
var ui: Control
var view: Node2D
var shop: HBoxContainer
var stats: Label
var phase_label: Label
var detail: RichTextLabel
var incoming: RichTextLabel
var message: Label
var start_button: Button
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
var shade: ColorRect
var speed_buttons=[]
var playback_speed=1
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
	zoom_gauge.position=Vector2(24,260)
	zoom_gauge.size=Vector2(40,260)
	ui.add_child(zoom_gauge)
	for value in [1,2,5]:
		var b=absolute_button("×"+str(value),Vector2(565+speed_buttons.size()*83,14),Vector2(73,33),func(): set_playback_speed(value))
		b.tooltip_text="Battle speed ×"+str(value)
		b.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size",18)
		speed_buttons.append(b)
	set_playback_speed(1)
	auto_button=absolute_button("Auto",Vector2(820,16),Vector2(53,29),func(): auto_camera=not auto_camera; update_zoom())
	auto_button.add_theme_font_size_override("font_size",14)
	var phase_panel=panel(ui,Rect2(1160,-9,280,80))
	var phase_content=Control.new()
	phase_panel.add_child(phase_content)
	phase_label=label(phase_content,"Shop",Vector2(0,1),30,Color("#414541"))
	phase_label.size=Vector2(256,42)
	phase_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var stripe=ColorRect.new()
	stripe.position=Vector2(-11,48)
	stripe.size=Vector2(279,23)
	stripe.color=Color("#ed7865")
	stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE
	phase_content.add_child(stripe)
	round_label=label(phase_content,"",Vector2(0,47),13,Color.WHITE)
	round_label.size=Vector2(256,24)
	round_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var hints=label(ui,"Scroll: zoom\nRMB / WASD: pan",Vector2(1200,96),12,Color("#e2e9ee"))
	hints.size=Vector2(216,40)
	hints.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	detail_panel=panel(ui,Rect2(76,85,340,0))
	var column=VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	detail_panel.add_child(column)
	detail_icon=TextureRect.new()
	detail_icon.custom_minimum_size=Vector2(300,98)
	detail_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(detail_icon)
	detail=RichTextLabel.new()
	detail.bbcode_enabled=true
	detail.custom_minimum_size=Vector2(310,0)
	detail.fit_content=true
	detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(detail)
	sell_button=button(column,"Sell",sell_selected,Vector2(0,32))
	detail_panel.hide()
	term_panel=panel(ui,Rect2(435,85,255,150))
	term_text=RichTextLabel.new()
	term_text.bbcode_enabled=true
	term_text.custom_minimum_size=Vector2(227,0)
	term_text.fit_content=true
	term_panel.add_child(term_text)
	term_panel.hide()
	income_panel=panel(ui,Rect2(1306,454,134,228),Color("#eb7b6a"))
	incoming=RichTextLabel.new()
	incoming.bbcode_enabled=true
	incoming.add_theme_font_override("normal_font",symbol_font)
	incoming.add_theme_font_override("bold_font",symbol_font)
	incoming.custom_minimum_size=Vector2(108,198)
	income_panel.add_child(incoming)
	currency_panel=panel(ui,Rect2(174,711,260,37))
	var pips=CurrencyPips.new()
	pips.game=self
	pips.custom_minimum_size=Vector2(234,24)
	currency_panel.add_child(pips)
	var bottom=panel(ui,Rect2(174,748,1092,104))
	bottom_panel=bottom
	var contents=Control.new()
	contents.custom_minimum_size=Vector2(1068,86)
	bottom.add_child(contents)
	xp_button=fixed_icon_button(contents,"⇈",func(): sim.buy_xp(); changed(),Vector2(70,70),30)
	xp_button.position=Vector2(0,5)
	xp_button.add_theme_font_size_override("font_size",30)
	var ring=XPRing.new()
	ring.game=self
	ring.size=Vector2(70,70)
	xp_button.add_child(ring)
	refresh_button=fixed_icon_button(contents,"⟳",func(): sim.roll_shop(); shop_page=0; changed(),Vector2(70,70),35)
	refresh_button.position=Vector2(76,5)
	refresh_button.add_theme_font_size_override("font_size",35)
	refresh_button.tooltip_text="Refresh shop · 1 coin"
	freeze_button=fixed_icon_button(contents,"❄",func(): sim.frozen=not sim.frozen; changed(),Vector2(70,70),31)
	freeze_button.position=Vector2(152,5)
	freeze_button.add_theme_font_size_override("font_size",31)
	shop=HBoxContainer.new()
	shop.position=Vector2(260,-5)
	shop.size=Vector2(630,94)
	shop.alignment=BoxContainer.ALIGNMENT_CENTER
	shop.add_theme_constant_override("separation",4)
	contents.add_child(shop)
	previous_button=button(contents,"‹",func(): shop_page=maxi(0,shop_page-1); refresh(),Vector2(28,50))
	previous_button.position=Vector2(230,14)
	next_button=button(contents,"›",func(): shop_page+=1; refresh(),Vector2(28,50))
	next_button.position=Vector2(900,14)
	start_button=fixed_icon_button(contents,"→",start_battle,Vector2(74,74),36)
	start_button.position=Vector2(982,3)
	start_button.add_theme_font_size_override("font_size",36)
	start_button.add_theme_stylebox_override("normal",style(Color("#fffdf6"),37,Color("#c0b8aa")))
	start_button.tooltip_text="Start infection"
	capacity_panel=panel(ui,Rect2(645,849,150,40))
	stats=Label.new()
	stats.add_theme_font_override("font",symbol_font)
	stats.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	capacity_panel.add_child(stats)
	shop_toggle=absolute_button("⌃",Vector2(175,704),Vector2(23,28),toggle_shop)
	shop_toggle.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	message=label(ui,"",Vector2(438,716),13,Color("#233d4d"))
	message.size=Vector2(785,25)
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

func show_menu():
	menu_open=true
	var col=clear_modal("MICROCOSM","Tiny cells. A big job.\nBuild your immune defense under the microscope.")
	button(col,"Continue",func(): modal.hide(); menu_open=false)
	if FileAccess.file_exists(save_path):
		button(col,"Load saved preparation",load_run)
	button(col,"New run · 12 rounds",func(): new_run(12))
	button(col,"New run · 10 rounds",func(): new_run(10))
	button(col,"How to play",show_help)
	button(col,"Quit",func(): save_run(); get_tree().quit())

func new_run(rounds):
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
	t.text="1. Drag a cell from the shop onto the field for 2 coins.\n2. Or select an offer, then click on the field to place it.\n3. Hold and drag the round arrow to rotate a cell.\n4. Merge matching cells: the third creates an elite.\n5. Bonds automatically hold hands with nearby cells.\n6. Unspent coins disappear between waves.\n\nBomb hurts friendly cells too. Keep your team safe!"
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
	button(col,"Back to the field",func(): modal.hide(); menu_open=false)

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
	stats.text="♟  %d / %d" % [sim.cells.size(),sim.capacity()]
	stats.tooltip_text="Immune cells / capacity"
	var names={"shop":"Shop","battle":"Infection","recap":"Recap","win":"Complete","lose":"Complete"}
	phase_label.text=names[sim.phase]
	round_label.text="Round %d / %d" % [mini(sim.round_no+1,sim.target_rounds) if sim.phase=="recap" else sim.round_no,sim.target_rounds]
	var display_wave=preview_wave if sim.phase=="recap" and not preview_wave.is_empty() else sim.wave
	incoming.text="[color=#fff6df][b]ⓘ Incoming[/b][/color]\n"
	for lane in range(3):
		var items=display_wave.filter(func(e): return e.lane==lane)
		if items.is_empty(): continue
		incoming.text+="\n[color=#663e4a]Lane "+str(lane+1)+"[/color]\n"
		for entry in items:
			incoming.text+="[color=#fff7e7]"+virus_glyph(entry.type)+" ×"+str(entry.count)+"[/color]\n"
	var is_shop=sim.phase=="shop"
	bottom_panel.visible=is_shop and not shop_collapsed
	currency_panel.visible=is_shop and not shop_collapsed
	capacity_panel.visible=is_shop and not shop_collapsed
	shop_toggle.visible=is_shop
	shop_toggle.position.y=704 if not shop_collapsed else 850
	shop_toggle.text="⌄" if not shop_collapsed else "⌃"
	if not is_shop:
		detail_panel.hide()
		term_panel.hide()
	elif not selected.is_empty() and sim.cells.has(selected):
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
	start_button.disabled=not is_shop or not sim.reward_choices.is_empty()
	xp_button.disabled=sim.money<3 or sim.tier>=4 or not is_shop
	xp_button.tooltip_text="Level %d · XP %d\nBuy XP · 3 coins" % [sim.tier,sim.xp]
	refresh_button.disabled=sim.money<1 or not is_shop
	freeze_button.disabled=not is_shop
	freeze_button.set("glyph","❄" if not sim.frozen else "❄▣")
	freeze_button.queue_redraw()
	freeze_button.tooltip_text="Shop frozen. Click to unfreeze." if sim.frozen else "Keep offers for the next round · free"
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
	if not sim.reward_choices.is_empty() and not modal.visible: show_reward()

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
		if not selected.is_empty(): show_cell_card(selected.key,selected)
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
	sim.release_blood()
	cancel_placement()
	save_run()
	sim.begin_battle()
	beep(420,0.16)
	dragging=false
	rotating=false
	refresh()

func changed():
	sim.rebuild_links()
	refresh()
	save_run()

func _process(delta):
	advance_camera(delta)
	advance_simulation(delta)
	if sim.phase!=last_phase:
		last_phase=sim.phase
		refresh()
		if sim.phase=="recap":
			show_recap()
		elif sim.phase in ["win","lose"]:
			var title="Defense successful!" if sim.phase=="win" else "No blood cells left"
			var col=clear_modal(title,"You survived "+str(sim.round_no)+" rounds.\n"+("All waves defeated." if sim.phase=="win" else "A new formation, a new chance."))
			button(col,"New run",func():new_run(sim.target_rounds))
			button(col,"Main menu",show_menu)
			if FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)
	if not modal.visible:
		var movement=Vector2(float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D)),float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S)))
		view.position+=movement*delta*280
	if sim.phase=="battle":
		stats.text="♟  %d / %d" % [sim.cells.size(),sim.capacity()]
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
		if event.keycode==KEY_ESCAPE:
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
	if modal.visible: return
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
				if not pending_offer.is_empty() and sim.phase=="shop":
					buy_offer_at(pending_offer.index,pending_offer.reward,world)
					return
				if sim.phase=="shop" and not selected.is_empty():
					var handle=selected.p+Vector2.RIGHT.rotated(selected.angle)*62
					if world.distance_to(handle)<14:
						rotating=true
						return
				selected={}
				for c in sim.cells:
					if c.alive and sim.contains_cell(c,world,6):
						selected=c
				if not selected.is_empty():
					dragging=sim.phase=="shop"
					mouse_offset=selected.p-world
				elif sim.phase=="shop":
					for i in range(sim.blood.size()):
						if sim.blood[i].alive and sim.blood[i].p.distance_to(world)<16:
							dragging_blood=i
							break
				refresh()
			else:
				if dragging and not selected.is_empty():
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
		if not pending_offer.is_empty(): view.drag_preview=world
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
		"choices":sim.reward_choices,"rng_state":str(sim.rng.state)}
	var file=FileAccess.open(save_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(data))

func load_run():
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
	playback_speed=value
	view.playback_speed=value
	for i in range(speed_buttons.size()):
		var active=value==[1,2,5][i]
		var box=StyleBoxFlat.new()
		box.bg_color=Color(0,0,0,0)
		box.border_width_bottom=2 if active else 0
		box.border_color=Color("#a5cf93")
		speed_buttons[i].add_theme_stylebox_override("normal",box)
		speed_buttons[i].add_theme_color_override("font_color",Color("#25495b") if active else Color("#6a8591"))

func advance_simulation(delta):
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
	if sim.phase!="shop": return
	detail_key=key
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

func virus_glyph(key):
	return {"basic":"✹","wave":"≈","jumper":"↟","hungry":"●","swarmer":"✣","seeker":"♟","avoider":"◇"}.get(key,"●")

func show_recap():
	var next_sim=Simulation.new()
	next_sim.reset(sim.seed_value,sim.target_rounds)
	next_sim.round_no=sim.round_no+1
	next_sim.make_wave()
	preview_wave=next_sim.wave.duplicate(true)
	var delta_type="basic"
	var delta_count=0
	for entry in preview_wave:
		var previous=0
		for old in sim.wave:
			if old.type==entry.type and old.lane==entry.lane: previous+=old.count
		if entry.count-previous>delta_count:
			delta_count=entry.count-previous
			delta_type=entry.type
	var col=clear_modal("Viral Load Increase!")
	showing_recap=true
	shade.color=Color(0,0,0,0)
	modal_panel.position=Vector2(475,122)
	modal_panel.size=Vector2(480,226)
	var amount=Label.new()
	amount.add_theme_font_override("font",symbol_font)
	amount.text=virus_glyph(delta_type)+"  + "+str(delta_count)
	amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override("font_size",40)
	amount.add_theme_color_override("font_color",Color("#9068ab"))
	col.add_child(amount)
	button(col,"Click to continue",advance_recap,Vector2(450,40))
	var virus_panel=panel(modal,Rect2(76,85,338,300))
	var box=VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	virus_panel.add_child(box)
	var title=Label.new()
	title.text=delta_type.capitalize()+" Virus"
	title.add_theme_font_size_override("font_size",27)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var glyph=Label.new()
	glyph.add_theme_font_override("font",symbol_font)
	glyph.text=virus_glyph(delta_type)
	glyph.add_theme_font_size_override("font_size",66)
	glyph.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_color_override("font_color",Color("#956eb0"))
	box.add_child(glyph)
	var facts=Label.new()
	facts.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	facts.custom_minimum_size=Vector2(305,92)
	facts.text=virus_description(delta_type)
	box.add_child(facts)
	refresh()

func advance_recap():
	if sim.phase!="recap": return
	sim.next_round()
	preview_wave=[]
	showing_recap=false
	shop_page=0
	modal.hide()
	menu_open=false
	changed()

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
	button(col,"Back",show_settings)
