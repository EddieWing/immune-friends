extends PanelContainer
# A passive guide: it observes successful game events and never mutates the run.
const STEPS=["purchase","place","rotate","pan","zoom","bonds","xp","merge","launch","free_xp"]
var game
var done={}
var active=false
var cursor=0
var angles={}
var body: Label
var acknowledge: Button
var current=""
var cooldown=0.0

func _ready():
	name="TutorialGuide"
	position=Vector2(370,76)
	custom_minimum_size=Vector2(700,0)
	add_theme_stylebox_override("panel",game.style(Color("#f1ecdb"),6,Color("#ac873e")))
	var column=VBoxContainer.new()
	add_child(column)
	body=Label.new()
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x=676
	body.add_theme_font_size_override("font_size",15)
	column.add_child(body)
	var row=HBoxContainer.new()
	column.add_child(row)
	acknowledge=game.button(row,"Got it",func():complete("free_xp"),Vector2(120,30))
	game.button(row,"Skip tutorial",skip,Vector2(150,30))
	hide()

func begin(reset=true):
	if reset:done={}
	active=true
	cursor=game.sim.event_sequence
	angles.clear()
	for cell in game.sim.cells:angles[cell.id]=cell.angle
	# A resumed/replayed guide does not require buying an already placed team again.
	if not game.sim.cells.is_empty():
		done.purchase=true
		done.place=true
	persist()
	refresh_hint()

func capture():
	return {"active":active,"done":done.duplicate()}

func restore(data):
	done={}
	if data is Dictionary and data.get("done") is Dictionary:
		for step in STEPS:
			if data.done.get(step,false)==true:done[step]=true
	active=data is Dictionary and data.get("active",false)==true
	cursor=game.sim.event_sequence
	angles.clear()
	for cell in game.sim.cells:angles[cell.id]=cell.angle
	refresh_hint()

func persist():
	game.settings.set_value("tutorial","progress",capture())
	game.settings.set_value("tutorial","seed",game.sim.seed_value)
	game.settings.save(game.settings_path)

func complete(step):
	if not active or game.gym_mode or done.has(step):return
	done[step]=true
	if done.size()==STEPS.size():active=false
	persist()
	refresh_hint()

func skip():
	active=false
	game.settings.set_value("tutorial","disabled",true)
	persist()
	hide()

func observe():
	if not active or game.gym_mode:return
	for event in game.sim.events_since(cursor):
		cursor=maxi(cursor,int(event.seq))
		match event.event:
			"purchase":complete("purchase");complete("place")
			"xp":complete("xp")
			"merge":
				if int(event.data.get("rank",1))>=3:complete("merge")
			"battle_start":complete("launch")
	if game.sim.phase=="shop":
		for cell in game.sim.cells:
			if game.sim.catalog[cell.key].behavior=="wall" and angles.has(cell.id) and absf(angle_difference(angles[cell.id],cell.angle))>0.08:complete("rotate")
			if not angles.has(cell.id):angles[cell.id]=cell.angle
		if not game.sim.links.is_empty():complete("bonds")

func eligible(step):
	var sim=game.sim
	match step:
		"purchase","place":return sim.money>=2 and sim.cells.size()<sim.capacity() and not sim.offers.is_empty()
		"rotate":return sim.cells.any(func(c):return sim.catalog[c.key].behavior=="wall")
		"bonds":return sim.cells.any(func(c):return sim.catalog[c.key].behavior=="bond")
		"xp":return sim.money>=int(sim.shop_rules.xp_price) and sim.tier<5
		"merge":
			for a in sim.cells:
				for b in sim.cells:
					if a.id!=b.id and sim.compatible(a,b):return true
				if a.rank<3 and a.key in sim.offers and sim.money>=2:return true
			return false
		"free_xp":return sim.round_no>1
	return true

func refresh_hint():
	if not is_instance_valid(body):return
	visible=active and not game.gym_mode and game.sim.phase=="shop" and not game.browsing_from_main_menu() and not game.entering_game and not game.modal.visible
	if not visible:return
	current=""
	# The round grant is information, not an action the player should repeat.
	var order=["free_xp"]+STEPS
	for step in order:
		if not done.has(step) and eligible(step):current=step;break
	var hints={
		"purchase":"Buy and place a cell: drag an offer onto the field, or select it and click a free spot. A successful purchase spends Carbons.",
		"place":"Place your purchased cell on the field. Cancelled placements do not spend Carbons.",
		"rotate":"Select a Wall. Hold its round arrow and turn it, or use the rotate button. Moving its body does not rotate it.",
		"pan":"Look around: hold the right mouse button and drag, or use WASD. The guide waits for actual camera movement.",
		"zoom":"Use the mouse wheel or the zoom slider to change magnification.",
		"bonds":"Move a connector near a partner until they hold hands. Hands show an actual bond; proximity alone is not a connection.",
		"xp":"Buy 1 XP with the +1 XP button. It costs %d Carbons; a level increases only when the XP threshold is reached." % int(game.sim.shop_rules.xp_price),
		"merge":"Drag matching cells together. The third copy makes an elite and offers a reward. Two copies are not yet an elite.",
		"launch":"Ready? Release Infection starts the battle. Unspent Carbons expire between rounds. Bombs can hurt friends too.",
		"free_xp":"New preparation grants +%d free XP. This is separate from buying XP; reaching a threshold increases capacity immediately." % int(game.sim.shop_rules.xp_per_round)}
	body.text="FIELD GUIDE · %d/%d\n" % [done.size(),STEPS.size()]+hints.get(current,"Continue your run. More tips appear when the required cells or Carbons are available.")
	acknowledge.visible=current=="free_xp"
	size.y=0

func _process(delta):
	observe()
	cooldown-=delta
	if cooldown<=0:
		cooldown=0.15
		refresh_hint()
