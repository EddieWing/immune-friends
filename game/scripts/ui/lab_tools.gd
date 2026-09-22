extends Control
var game
var gym_panel: PanelContainer
var debug_panel: PanelContainer
var readout: Label
var hint: Label
var cells: OptionButton
var viruses: OptionButton
var inspect_button: Button
var rank: OptionButton
var cell_keys=[]
var virus_keys=["basic","wave","jumper","hungry","swarmer","seeker","avoider"]
var clock=0.0
var debug_hint: Label
var debug_cells: OptionButton
var debug_viruses: OptionButton
var debug_count: SpinBox
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 theme=game.ui.theme
 gym_panel=game.panel(self,Rect2(20,95,270,0))
 var col=VBoxContainer.new()
 col.add_theme_constant_override("separation",7)
 gym_panel.add_child(col)
 var title=Label.new()
 title.text="GYM · Sandbox"
 title.add_theme_font_size_override("font_size",24)
 col.add_child(title)
 cells=OptionButton.new()
 cell_keys=["__core"]+game.sim.available_cell_keys()
 for key in cell_keys: cells.add_item("Core cell" if key=="__core" else game.sim.catalog[key].name)
 col.add_child(cells)
 rank=OptionButton.new()
 for text in ["Normal · 1/3","Merged · 2/3","Elite · 3/3"]: rank.add_item(text)
 col.add_child(rank)
 cells.select(1)
 cells.item_selected.connect(func(index): rank.disabled=cell_keys[index]=="__core")
 game.button(col,"Place cell",func(): arm("cell",cell_keys[cells.selected]),Vector2(246,34))
 viruses=OptionButton.new()
 for key in virus_keys: viruses.add_item(key.capitalize()+" Virus")
 col.add_child(viruses)
 game.button(col,"Place virus",func(): arm("virus",virus_keys[viruses.selected]),Vector2(246,34))
 game.button(col,"Remove object",func(): arm("remove",""),Vector2(246,34))
 game.button(col,"Run / Resume",game.gym_run,Vector2(246,34))
 game.button(col,"Pause",func(): game.paused=true; game.update_transport(),Vector2(246,34))
 game.button(col,"Reset setup",game.gym_reset_setup,Vector2(246,34))
 game.button(col,"Clear field",game.gym_clear,Vector2(246,34))
 game.button(col,"Restore core cells",game.gym_restore_core,Vector2(246,34))
 hint=Label.new()
 hint.custom_minimum_size=Vector2(246,0)
 hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 hint.text="Choose an object, then click the field. Esc cancels. F3: debug tools."
 col.add_child(hint)
 game.button(col,"Back to main menu",game.leave_gym,Vector2(246,34))
 inspect_button=game.button(col,"Inspect cells · Shift+T",game.cell_tuner.toggle,Vector2(246,34))
 inspect_button.toggle_mode=true
 gym_panel.hide()
 debug_panel=game.panel(self,Rect2(12,12,370,0),Color.BLACK)
 var debug_theme=Theme.new()
 debug_theme.default_font=preload("res://assets/fonts/CascadiaMono.ttf")
 debug_theme.default_font_size=13
 for type in ["Label","Button","CheckButton","OptionButton","SpinBox","LineEdit"]:
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
   debug_theme.set_color(state,type,Color("#e0f5e9"))
  debug_theme.set_color("font_disabled_color",type,Color("#65766c"))
 for state in ["normal","hover","pressed","disabled","focus"]:
  var fill=Color("#101813") if state=="normal" else Color("#21362a")
  if state=="focus": fill=Color.TRANSPARENT
  var skin=game.style(fill,2,Color("#446454"))
  for control in ["Button","OptionButton","LineEdit"]: debug_theme.set_stylebox(state,control,skin)
 debug_panel.theme=debug_theme
 var frame=game.style(Color.BLACK,2,Color("#547764"))
 frame.set_border_width_all(1)
 debug_panel.add_theme_stylebox_override("panel",frame)
 var debug=VBoxContainer.new()
 debug.add_theme_constant_override("separation",8)
 var scroll=ScrollContainer.new()
 scroll.custom_minimum_size=Vector2(370,760)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 debug_panel.add_child(scroll)
 debug.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(debug)
 readout=Label.new()
 readout.custom_minimum_size=Vector2(346,0)
 readout.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 readout.add_theme_font_size_override("font_size",14)
 debug.add_child(readout)
 for entry in [["Colliders", "debug_geometry"], ["Travel paths", "debug_paths"], ["Movement vectors", "debug_vectors"]]:
  var toggle=CheckButton.new()
  toggle.text=entry[0]
  toggle.button_pressed=game.view.get(entry[1])
  toggle.toggled.connect(func(value): game.view.set(entry[1],value))
  debug.add_child(toggle)
 debug_cells=OptionButton.new()
 for key in cell_keys: debug_cells.add_item("Core cell" if key=="__core" else game.sim.catalog[key].name)
 debug_cells.select(1)
 debug.add_child(debug_cells)
 game.button(debug,"Spawn cell at click",func(): debug_arm("cell",cell_keys[debug_cells.selected]))
 debug_viruses=OptionButton.new()
 for key in virus_keys: debug_viruses.add_item(key.capitalize()+" Virus")
 debug.add_child(debug_viruses)
 var row=HBoxContainer.new()
 debug.add_child(row)
 debug_count=SpinBox.new()
 debug_count.min_value=1
 debug_count.max_value=100
 debug_count.value=5
 debug_count.tooltip_text="Viruses released by the new source."
 row.add_child(debug_count)
 game.button(row,"Spawn source",func(): debug_arm("source",virus_keys[debug_viruses.selected]))
 game.button(debug,"Replenish lost core cells",game.debug_replenish_core)
 debug_hint=Label.new()
 debug_hint.custom_minimum_size=Vector2(346,0)
 debug_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 debug_hint.text="Select a type, then click the field. Esc cancels."
 debug.add_child(debug_hint)
 game.button(debug,"Pause / Resume",func():
  if game.sim.phase=="battle" and game.launch_remaining==0:
   game.paused=not game.paused
   game.update_transport())
 game.button(debug,"Step · 1/60 s",func():
  if game.paused and game.sim.phase=="battle" and game.launch_remaining==0: game.sim.update(1.0/60.0))
 game.button(debug,"+10 Carbons (current session)",func(): game.sim.money+=10; game.refresh())
 game.button(debug,"Close · F3",debug_panel.hide)
 debug_panel.hide()
func debug_arm(kind,key):
 if game.browsing_from_main_menu() or game.launch_remaining>0 or game.sim.phase not in ["shop","battle"]:
  debug_hint.text="Enter preparation or infection first."
  return
 game.paused=game.sim.phase=="battle"
 game.update_transport()
 game.cancel_placement()
 game.gym_tool={"kind":kind,"key":key,"rank":1,"debug":true,"count":int(debug_count.value)}
 debug_hint.text="Click the field to place "+key.replace("_"," ")+". Esc cancels; resume manually."
func arm(kind,key):
 if game.sim.phase=="battle" and not game.paused:
  hint.text="Pause the test before placing or removing objects."
  return
 if game.cell_tuner.enabled: game.cell_tuner.toggle()
 game.gym_tool={"kind":kind,"key":key,"rank":rank.selected+1}
 hint.text="Click the field to "+("remove an object" if kind=="remove" else "place "+key.replace("_"," "))+". Esc cancels."
func _process(delta):
 gym_panel.visible=game.gym_mode and not game.browsing_from_main_menu() and not (game.modal.visible and is_instance_valid(game.modal_panel) and game.modal_panel.get_meta("cell_tuner",false))
 inspect_button.set_pressed_no_signal(game.cell_tuner.enabled)
 inspect_button.text="Inspect cells · ON" if game.cell_tuner.enabled else "Inspect cells · Shift+T"
 gym_panel.position.x=1150 if debug_panel.visible else 20
 clock+=delta
 if clock<0.2 or not debug_panel.visible: return
 clock=0
 var sim=game.sim
 var text="DEBUG · F3\n%s · %s · %.2f s · ×%d\nFPS: %d\nCells: %d  Core: %d  Viruses: %d\nBonds: %d  Particles: %d\nQueued viruses: %d" % ["GYM" if game.gym_mode else "RUN",sim.phase+ (" / paused" if game.paused else ""),sim.elapsed,game.playback_speed,Engine.get_frames_per_second(),sim.cells.filter(func(c): return c.alive).size(),sim.blood.filter(func(b): return b.alive).size(),sim.viruses.size(),sim.links.size(),sim.particles.size(),sim.spawn_queue.size()]
 if not game.selected.is_empty():
  var c=game.selected
  text+="\nSelected: %s\nHP %.1f / %.1f · rank %d\nAbility timer: %.2f" % [c.key,c.hp,c.max_hp,c.rank,c.cool]
 text+="\nRecent events:"
 for i in range(maxi(0,sim.events.size()-3),sim.events.size()): text+="\n"+sim.events[i].event
 readout.text=text

func refresh_available():
 cell_keys=["__core"]+game.sim.available_cell_keys()
 virus_keys=game.sim.available_virus_keys()
 for dropdown in [cells,debug_cells]:
  dropdown.clear()
  for key in cell_keys: dropdown.add_item("Core cell" if key=="__core" else game.sim.catalog[key].name)
  dropdown.select(1)
 for dropdown in [viruses,debug_viruses]:
  dropdown.clear()
  for key in virus_keys: dropdown.add_item(key.capitalize()+" Virus")
  dropdown.select(0)
 rank.disabled=false
