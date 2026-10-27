extends Control
const INK=Color("#292b29")
const PAPER=Color("#f1ecdb")
const GOLD=Color("#dbaf54")
const MUTED=Color("#9c9580")
const DARK=Color("#252b2d")
const RED=Color("#b52e4a")
var game
var shelf: ScrollContainer
var offers: HBoxContainer
var release: Button
var upgrade: Button
var refresh_button: Button
var freeze: Button
var sell: Button
var rotate: Button
var transport=[]
var note: PanelContainer
var note_rows: VBoxContainer
var forecast: PanelContainer
var forecast_rows: VBoxContainer
var cell_key=""
var cell={}
var virus_key=""
var virus_lane=0
var seen_round=-1
var seen_sim
var seen_types=[]
var previous_types=[]
var previous_wave=[]
var signature=""
var cell_rect=Rect2(342,208,286,242)
var virus_rect=Rect2(1046,208,268,210)
var cell_block: Control
var virus_block: Control
var dock_offset=0.0
var active=false
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shelf=ScrollContainer.new()
 shelf.name="OfferShelf"
 shelf.position=Vector2(332,752)
 shelf.size=Vector2(728,128)
 shelf.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 shelf.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
 add_child(shelf)
 offers=HBoxContainer.new()
 offers.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 offers.alignment=BoxContainer.ALIGNMENT_CENTER
 offers.add_theme_constant_override("separation",8)
 shelf.add_child(offers)
 release=action("RELEASE\nINFECTION",Rect2(1196,760,214,124),func():game.set_playback_speed(1);game.start_battle(),true)
 upgrade=action("",Rect2(209,778,62,62),func():game.sim.buy_xp();game.changed())
 refresh_button=action("⟳",Rect2(1082,754,56,56),func():game.sim.roll_shop();game.changed())
 freeze=action("❄",Rect2(1082,818,56,56),func():game.sim.frozen=not game.sim.frozen;game.changed())
 for b in [refresh_button,freeze]:
  for state in ["normal","hover","pressed","disabled"]: b.get_theme_stylebox(state).set_corner_radius_all(28)
 for value in [0,1,2,5]:
  var b=action("Ⅱ" if value==0 else "×"+str(value),Rect2(574+transport.size()*64,14,56,44),func():
   if value==0: game.paused=true;game.update_transport()
   else: game.set_playback_speed(value))
  b.set_meta("speed",value)
  transport.append(b)
 note=paper_panel(Rect2(24,84,230,0))
 note_rows=VBoxContainer.new()
 note_rows.add_theme_constant_override("separation",8)
 var note_scroll=ScrollContainer.new()
 note_scroll.custom_minimum_size=Vector2(204,230)
 note_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 note.add_child(note_scroll)
 note_scroll.add_child(note_rows)
 note_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 forecast=paper_panel(Rect2(40,110,352,0))
 forecast_rows=VBoxContainer.new()
 forecast_rows.custom_minimum_size.x=328
 forecast_rows.add_theme_constant_override("separation",10)
 forecast.add_child(forecast_rows)
 cell_block=Control.new()
 cell_block.position=cell_rect.position
 cell_block.size=cell_rect.size
 add_child(cell_block)
 virus_block=Control.new()
 virus_block.position=virus_rect.position
 virus_block.size=virus_rect.size
 add_child(virus_block)
 sell=action("SELL",Rect2(355,407,211,39),game.sell_selected,true)
 rotate=action("⟳",Rect2(574,407,42,39),func():
  if not cell.is_empty() and game.sim.cells.has(cell):
   cell.angle+=PI/6
   game.changed())
 refresh_data()
func action(caption,rect,callback,gold=false):
 var b=Button.new()
 b.text=caption
 b.position=rect.position
 b.size=rect.size
 b.add_theme_font_override("font",game.symbol_font)
 b.add_theme_font_size_override("font_size",18 if gold else 16)
 for state in ["normal","hover","pressed","disabled"]:
  var box=game.style(GOLD if gold else DARK,2,Color("#a78540") if gold else Color("#565649"))
  box.content_margin_top=3
  box.content_margin_bottom=3
  box.content_margin_left=4
  box.content_margin_right=4
  if state=="hover": box.bg_color=box.bg_color.lightened(0.1)
  if state=="pressed": box.bg_color=box.bg_color.darkened(0.1)
  if state=="disabled": box.bg_color=box.bg_color.darkened(0.3)
  b.add_theme_stylebox_override(state,box)
 for state in ["font_color","font_hover_color","font_pressed_color"]: b.add_theme_color_override(state,INK if gold else Color("#dccba3"))
 b.pressed.connect(callback)
 add_child(b)
 return b
func paper_panel(rect):
 var panel=PanelContainer.new()
 panel.position=rect.position
 panel.size=rect.size
 panel.add_theme_stylebox_override("panel",game.style(PAPER,2,Color("#c0b49a")))
 var paper=preload("res://scripts/ui/lab_paper.gd").new()
 panel.add_child(paper)
 add_child(panel)
 return panel
func line(parent,text,color=INK,size_font=14):
 var l=Label.new()
 l.text=text.replace("●","•").replace("★","+")
 l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size",size_font)
 l.add_theme_color_override("font_color",color)
 l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 parent.add_child(l)
 return l
func pair(parent,left,right,color=INK,size_font=14):
 var row=HBoxContainer.new()
 parent.add_child(row)
 var a=line(row,left,color,size_font)
 a.autowrap_mode=TextServer.AUTOWRAP_OFF
 a.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var b=line(row,str(right),color,size_font)
 b.autowrap_mode=TextServer.AUTOWRAP_OFF
 b.size_flags_horizontal=Control.SIZE_SHRINK_END
 return row
func fit_note():
 await get_tree().process_frame
 await get_tree().process_frame
 if not is_instance_valid(note):return
 var scroll=note.get_child(1)
 scroll.custom_minimum_size.y=clampf(note_rows.get_combined_minimum_size().y,100,490)
 note.size.y=0
func clear_rows(parent):
 for child in parent.get_children():
  parent.remove_child(child)
  child.queue_free()
func total(wave):
 var value=0
 for entry in wave: value+=int(entry.count)
 return value
func lanes(wave):
 var result=[]
 for entry in wave:
  if entry.lane not in result: result.append(entry.lane)
 result.sort()
 return result
func count_type(wave,lane,kind):
 var value=0
 for e in wave:
  if e.lane==lane and e.type==kind: value+=e.count
 return value
func new_types(wave):
 var result=[]
 for entry in wave:
  if entry.type not in previous_types and entry.type not in result: result.append(entry.type)
 return result
func observe_wave():
 if seen_sim!=game.sim or seen_round>game.sim.round_no:
  seen_sim=game.sim
  seen_round=-1
  seen_types=[]
  previous_types=[]
  previous_wave=[]
 if seen_round!=game.sim.round_no:
  cell_key=""
  virus_key=""
  previous_types=seen_types.duplicate()
  if seen_round>=0: previous_wave=game.sim.wave.duplicate(true)
  seen_round=game.sim.round_no
 for entry in game.sim.wave:
  if entry.type not in seen_types: seen_types.append(entry.type)
func refresh_data():
 if not is_node_ready(): return
 observe_wave()
 clear_rows(offers)
 for reward in [false,true]:
  var items=game.sim.rewards if reward else game.sim.offers
  for index in range(items.size()):
   var key=items[index]
   var card=preload("res://scripts/ui/offer.gd").new()
   card.game=game
   card.key=key
   card.index=index
   card.reward=reward
   card.category=game.sim.catalog[key].category
   card.icon_texture=game.cell_icon(key)
   card.modern=true
   card.custom_minimum_size=Vector2(113,118)
   card.tooltip_text=game.sim.catalog[key].name
   var can_merge=game.sim.cells.any(func(c):return c.key==key and c.rank<3 or c.key=="wildcard" and c.rank<3 or key=="wildcard" and c.rank<3)
   card.disabled=game.sim.phase!="shop" or (not reward and game.sim.money<2) or (game.sim.cells.size()>=game.sim.capacity() and not can_merge)
   card.pressed.connect(func():game.arm_offer(index,reward))
   card.mouse_entered.connect(func():select_cell(key,{}))
   card.mouse_exited.connect(func():
    if not game.selected.is_empty():select_cell(game.selected.key,game.selected)
    elif game.pending_offer.is_empty():cell_key="")
   offers.add_child(card)
 clear_rows(note_rows)
 line(note_rows,"WAVE %02d       %d SOURCES" % [game.sim.round_no,lanes(game.sim.wave).size()],MUTED,11)
 pair(note_rows,"INCOMING",total(game.sim.wave),INK,18)
 for lane in lanes(game.sim.wave):
  var count=0
  for e in game.sim.wave:
   if e.lane==lane: count+=e.count
  pair(note_rows,"● Source %d" % (lane+1),count,RED,14)
  for e in game.sim.wave:
   if e.lane!=lane:continue
   var row=pair(note_rows,"   "+e.type.capitalize(),"×%d" % e.count)
   row.mouse_filter=Control.MOUSE_FILTER_STOP
   row.tooltip_text="Double-click to open Virus File"
   row.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click: select_virus(e.type,lane))
 var types=new_types(game.sim.wave)
 if not types.is_empty():line(note_rows,"★ NEW TYPE  "+", ".join(types).capitalize(),RED,12)
 note.get_child(1).custom_minimum_size.y=minf(490,62+lanes(game.sim.wave).size()*28+game.sim.wave.size()*29+(35 if not types.is_empty() else 0))
 note.size.y=0
 fit_note.call_deferred()
 signature=JSON.stringify(game.sim.wave)
func select_cell(key,instance):
 cell_key=key
 cell=instance
 var width=game.symbol_font.get_string_size(game.sim.catalog[key].description,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
 cell_rect.size.y=maxf(242,165+ceil(width/240.0)*18+50)
 cell_block.size=cell_rect.size
 sell.position.y=cell_rect.end.y-60
 rotate.position.y=sell.position.y
func select_virus(key,lane):
 virus_key=key
 virus_lane=lane
func forecast_row(parent, title, before, after, color=INK, font_size=14):
 var row=HBoxContainer.new()
 row.add_theme_constant_override("separation",8)
 parent.add_child(row)
 var name_label=line(row,title,color,font_size)
 name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for value in [before,after]:
  var number=line(row,str(value),color,font_size)
  number.autowrap_mode=TextServer.AUTOWRAP_OFF
  number.custom_minimum_size.x=64
  number.size_flags_horizontal=Control.SIZE_FILL
  number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 return row

func build_forecast():
 clear_rows(forecast_rows)
 line(forecast_rows,"FORECAST · ROUND %02d" % (game.sim.round_no+1),MUTED,11)
 line(forecast_rows,"Next wave",INK,24)
 var scroll=ScrollContainer.new()
 scroll.custom_minimum_size=Vector2(0,285)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 forecast_rows.add_child(scroll)
 var rows=VBoxContainer.new()
 rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 rows.add_theme_constant_override("separation",8)
 scroll.add_child(rows)
 forecast_row(rows,"VIRUSES","WAS","NEXT",MUTED,11)
 forecast_row(rows,"Total",total(game.sim.wave),total(game.preview_wave),RED,18)
 for lane in lanes(game.preview_wave):
  var old_count=0
  var new_count=0
  for e in game.sim.wave:
   if e.lane==lane:old_count+=e.count
  for e in game.preview_wave:
   if e.lane==lane:new_count+=e.count
  var source_header=pair(rows,"Source %d" % (lane+1),"NEW" if old_count==0 else "GROWING" if new_count>old_count else "",RED,13)
  source_header.custom_minimum_size.y=28
  var kinds=[]
  for e in game.preview_wave+game.sim.wave:
   if e.lane==lane and e.type not in kinds:kinds.append(e.type)
  for kind in kinds:
   var before=count_type(game.sim.wave,lane,kind)
   var after=count_type(game.preview_wave,lane,kind)
   forecast_row(rows,kind.capitalize(),str(before) if before else "—",after)
 var types=[]
 for e in game.preview_wave:
  if e.type not in seen_types and e.type not in types:types.append(e.type)
 for kind in types:
  line(rows,"★ NEW TYPE · "+kind.capitalize(),RED,15)
  line(rows,game.wave_trait(kind),INK,13)
 var button=Button.new()
 button.add_theme_font_override("font",game.symbol_font)
 button.text="TO PREPARATION →\n%d Carbons available" % game.sim.next_budget()
 button.custom_minimum_size=Vector2(0,62)
 button.add_theme_stylebox_override("normal",game.style(GOLD,2,Color("#906b23")))
 button.add_theme_font_size_override("font_size",16)
 button.pressed.connect(game.advance_recap)
 forecast_rows.add_child(button)
 forecast.size.y=0
 fit_forecast.call_deferred()
func fit_forecast():
 await get_tree().process_frame
 await get_tree().process_frame
 if not is_instance_valid(forecast):return
 for child in forecast_rows.get_children():
  if child is ScrollContainer:child.custom_minimum_size.y=clampf(child.get_child(0).get_combined_minimum_size().y,80,360)
 await get_tree().process_frame
 if is_instance_valid(forecast):forecast.size=forecast.get_combined_minimum_size()
func _process(delta):
 var was_active=active
 active=game.ui_new and not game.gym_mode
 if was_active and not active:
  game.refresh()
  game.dock.visible=game.sim.phase=="shop" and not game.gym_mode
  for old in game.speed_buttons:old.show()
 visible=active and not game.browsing_from_main_menu()
 if not active:return
 for old in [game.dock,game.phase_panel,game.income_panel,game.detail_panel,game.term_panel,game.scanner]:old.hide()
 for old in game.speed_buttons:old.hide()
 if game.browsing_from_main_menu():return
 if signature!=JSON.stringify(game.sim.wave) or seen_sim!=game.sim or seen_round!=game.sim.round_no:refresh_data()
 # Refit after width-dependent wrapping settles, including the initial entry.
 var note_scroll=note.get_child(1)
 var note_height=clampf(note_rows.get_combined_minimum_size().y,100,490)
 if not is_equal_approx(note_scroll.custom_minimum_size.y,note_height):
  note_scroll.custom_minimum_size.y=note_height
  note.size.y=0
 var prep=game.sim.phase=="shop" and game.launch_remaining<=0
 var combat=game.sim.phase=="battle" and game.launch_remaining<=0
 var preview=game.results_stage=="forecast"
 if preview and is_instance_valid(game.modal_panel) and game.modal_panel.get_meta("field_report",false):game.modal.hide()
 dock_offset=move_toward(dock_offset,0 if game.shopping_in_focus() else 190,delta*190/0.3)
 release.visible=prep
 for button in [upgrade,refresh_button,freeze]:button.visible=game.shopping_in_focus()
 shelf.visible=game.shopping_in_focus() or dock_offset<190
 shelf.mouse_filter=Control.MOUSE_FILTER_STOP if game.shopping_in_focus() else Control.MOUSE_FILTER_IGNORE
 offers.mouse_filter=shelf.mouse_filter
 shelf.position.y=752+dock_offset
 release.disabled=not game.sim.reward_choices.is_empty()
 if release.get_theme_font_size("font_size")!=23: release.add_theme_font_size_override("font_size",23)
 upgrade.visible=game.shopping_in_focus() and game.sim.tier<5
 upgrade.disabled=game.sim.money<3
 refresh_button.tooltip_text="Refresh · 1 Carbon"
 refresh_button.disabled=game.sim.money<1
 freeze.modulate=Color("#96d6ff") if game.sim.frozen else Color.WHITE
 if upgrade.get_theme_font_size("font_size")!=15: upgrade.add_theme_font_size_override("font_size",15)
 upgrade.text="+1 XP"
 upgrade.tooltip_text=game.xp_purchase_tooltip()
 note.visible=prep
 forecast.visible=preview
 for b in transport:
  b.visible=combat
  var is_active=(b.get_meta("speed")==0 if game.paused else b.get_meta("speed")==game.playback_speed)
  var font_color=GOLD if is_active else MUTED
  if b.get_theme_color("font_color")!=font_color: b.add_theme_color_override("font_color",font_color)
  var border_color=GOLD if is_active else Color("#565649")
  var skin=b.get_theme_stylebox("normal")
  if skin.border_color!=border_color: skin.border_color=border_color
 if not cell.is_empty() and (not cell.get("alive",false) or not game.sim.cells.has(cell)):cell_key=""
 if prep and not game.selected.is_empty() and not shelf.get_global_rect().has_point(get_global_mouse_position()) and game.pending_offer.is_empty():
  if cell!=game.selected:select_cell(game.selected.key,game.selected)
 cell_block.visible=prep and cell_key!=""
 virus_block.visible=prep and virus_key!=""
 sell.visible=cell_block.visible and not cell.is_empty()
 rotate.visible=sell.visible
 sell.disabled=not prep
 sell.text="SELL  ● %d" % int(cell.get("sale",1))
 queue_redraw()
func text(p,value,size_font=14,color=INK):
 draw_string(game.symbol_font,p,str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,size_font,color)
func box(rect,color,border=Color.TRANSPARENT):
 var style=game.style(color,2,border)
 style.shadow_size=8
 style.shadow_color=Color(0,0,0,0.22)
 draw_style_box(style,rect)
func paper(rect):
 box(rect,PAPER,Color("#bcb39a"))
 for y in range(int(rect.position.y)+23,int(rect.end.y)-6,23):draw_line(Vector2(rect.position.x+8,y),Vector2(rect.end.x-8,y),Color(0.45,0.4,0.3,0.10),1)
func wrapped_text(p,value,width,size_font=14,color=INK):
 var row=""
 var y=p.y
 for word in value.split(" "):
  if game.symbol_font.get_string_size(row+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size_font).x>width and row!="":
   text(Vector2(p.x,y),row,size_font,color)
   y+=size_font+5
   row=""
  row+=word+" "
 text(Vector2(p.x,y),row,size_font,color)
func _draw():
 if not active or game.browsing_from_main_menu():return
 var sim=game.sim
 var prep=sim.phase=="shop" and game.launch_remaining<=0
 var combat=sim.phase=="battle" and game.launch_remaining<=0
 if prep:
  box(Rect2(470,14,500,52),DARK,Color("#5e5b48"))
  text(Vector2(487,40),"●  PREPARATION",12,GOLD)
  text(Vector2(819,40),"ROUND %02d / %02d" % [sim.round_no,sim.target_rounds],16,Color("#eee7d4"))
  for i in range(sim.target_rounds):draw_rect(Rect2(487+i*466.0/sim.target_rounds,51,466.0/sim.target_rounds-3,4),GOLD if i<sim.round_no else Color("#4c5151"))
 if dock_offset<190:
  draw_set_transform(Vector2(0,dock_offset))
  box(Rect2(320,742,752,142),Color("#c9e2eb55"),Color("#e8dfbd"))
  text(Vector2(322,730),"ROOM FOR %d MORE CELLS" % maxi(0,sim.capacity()-sim.cells.size()),12,GOLD if sim.cells.size()<sim.capacity() else RED)
  box(Rect2(209,847,92,30),DARK,Color("#5c5846"))
  text(Vector2(220,868),"○ %d / %d" % [sim.cells.size(),sim.capacity()],16,Color("#f0ead7"))
  var flask=PackedVector2Array([Vector2(62,772),Vector2(94,772),Vector2(86,772),Vector2(86,808),Vector2(112,865),Vector2(102,879),Vector2(51,879),Vector2(42,865),Vector2(70,808),Vector2(70,772),Vector2(62,772)])
  draw_polyline(flask,Color("#aebdc0"),3,true)
  for i in range(mini(18,sim.money)):draw_circle(Vector2(55+(i%6)*9,870-int(i/6)*8),4,GOLD)
  text(Vector2(151,850),str(sim.money),34,GOLD)
  text(Vector2(136,870),"CARBONS",10,MUTED)
  if sim.tier<5:
   text(Vector2(209,769),"LV %d · XP %d/%d" % [sim.tier,sim.xp,int(sim.rules.xp_thresholds[sim.tier-1])],11,GOLD)
   var prev=0 if sim.tier==1 else int(sim.rules.xp_thresholds[sim.tier-2])
   var goal=int(sim.rules.xp_thresholds[sim.tier-1])
   var steps=maxi(1,goal-prev)
   for i in range(steps):
    var y=778+(steps-i-1)*62.0/steps
    box(Rect2(280,y,21,62.0/steps-3),Color("#715c28") if sim.xp-prev>i else DARK,Color("#6e654e"))
    for dot in range(3):draw_circle(Vector2(284+dot*6,y+(62.0/steps-3)/2),1.5,GOLD if sim.xp-prev>i else MUTED)
  draw_set_transform(Vector2.ZERO)
 if prep and cell_key!="":
  if not cell.is_empty():
   var anchor=game.view.to_global(cell.p)
   var edge=Vector2(cell_rect.end.x,clampf(anchor.y,cell_rect.position.y+20,cell_rect.end.y-20))
   draw_polyline(PackedVector2Array([anchor,Vector2(edge.x+20,edge.y),edge]),Color("#987f48"),1,true)
  draw_cell_record()
 if prep and virus_key!="":draw_virus_record()
 if combat:
  draw_combat()
  draw_alert()
  box(Rect2(24,835,215,42),DARK,Color("#665d42"))
  text(Vector2(40,862),"♧ %d  Carbons" % sim.money,15,GOLD)
  text(Vector2(163,861),"Mint +%d" % sim.battle_income,12,Color("#96dcb0"))
 if game.view.staging=="warning" or prep:draw_source_labels()
func draw_cell_record():
 paper(cell_rect)
 var d=game.sim.catalog[cell_key]
 text(Vector2(355,231),"○ LAB RECORD",10,MUTED)
 text(Vector2(558,231),"REWARD" if int(d.tier)==0 else "TIER %d" % int(d.tier),10,INK)
 draw_texture_rect(game.cell_icon(cell_key),Rect2(355,244,54,54),false)
 wrapped_text(Vector2(420,263),d.name,190,16)
 text(Vector2(420,289),d.category+"  RANK "+"▲".repeat(int(cell.get("rank",1)))+"△".repeat(3-int(cell.get("rank",1))),11)
 text(Vector2(355,322),"♥ %s / %s" % [str(cell.get("hp",d.hp)),str(cell.get("max_hp",d.hp))],16,RED)
 text(Vector2(355,342),"ABILITY",10,MUTED)
 wrapped_text(Vector2(355,363),d.description,259,13)
func draw_virus_record():
 paper(virus_rect)
 text(Vector2(1059,231),"VIRUS FILE   SOURCE %d" % (virus_lane+1),10,MUTED)
 draw_set_transform(Vector2(1083,270),0,Vector2.ONE*1.4)
 preload("res://scripts/virus_visuals.gd").draw(self,{"p":Vector2.ZERO,"type":virus_key,"jump":false,"tag":0,"hp":1})
 draw_set_transform(Vector2.ZERO)
 text(Vector2(1113,267),virus_key.capitalize(),20)
 var count=count_type(game.sim.wave,virus_lane,virus_key)
 text(Vector2(1254,267),str(count),22,RED)
 var stats=game.sim.tuning.get("virus:"+virus_key,{})
 var hp=stats.get("hp",2 if virus_key=="seeker" else 1)
 text(Vector2(1059,296),"♥ %s   → %s   ATK 1" % [str(hp),str(snappedf(float(game.sim.rules.virus_speed)*float(stats.get("speed_multiplier",1)),0.1))],15)
 wrapped_text(Vector2(1059,328),game.wave_trait(virus_key),242,14)
 if virus_key in new_types(game.sim.wave):text(Vector2(1059,402),"★ NEW TYPE",11,RED)
func draw_combat():
 var sim=game.sim
 var source_ids=lanes(sim.wave)
 var height=218+source_ids.size()*25
 box(Rect2(24,82,266,height),DARK,Color("#615c49"))
 text(Vector2(40,107),"☼ INFECTION · ROUND %02d" % sim.round_no,11,Color("#c8b990"))
 var alive=sim.viruses.filter(func(v):return v.alive).size()
 var killed=int(sim.round_losses.viruses)
 var count=maxi(total(sim.wave),alive+killed+sim.spawn_queue.size())
 text(Vector2(40,142),"Viruses on field",14,Color("#e9ddbc"))
 text(Vector2(247,143),str(alive),21,Color("#fff4d9"))
 draw_rect(Rect2(40,155,234,6),Color("#444a4c"))
 draw_rect(Rect2(40,155,234*clampf(float(alive)/maxi(1,count),0,1),6),RED)
 text(Vector2(40,179),"KILLED %d     TOTAL %d" % [killed,count],11,MUTED)
 var y=213
 for lane in source_ids:
  var releasing=sim.source_releasing(lane)
  var waiting=sim.spawn_queue.any(func(e):return e.lane==lane)
  text(Vector2(42,y),"● Source %d" % (lane+1),14,Color("#e9ddbc"))
  text(Vector2(173,y),"+ RELEASING" if releasing else ("— WAITING" if waiting else "— QUIET"),11,Color("#f093a0") if releasing else MUTED)
  y+=25
 y+=18
 var core=sim.blood.filter(func(c):return c.alive).size()
 var cells=sim.cells.filter(func(c):return c.alive).size()
 var bonds=0
 for link in sim.links:
  var a=sim.endpoint_by_id(link.a)
  var b=sim.endpoint_by_id(link.b)
  if not a.is_empty() and not b.is_empty() and a.alive and b.alive:bonds+=1
 for link in sim.blood_links:
  if sim.blood[link.a].alive and sim.blood[link.b].alive:bonds+=1
 for row in [["● Core alive",str(core)+" / "+str(sim.blood.size()),Color("#f28697")],["∞ Bonds",str(bonds),Color("#96cde2")],["○ Cells alive",str(cells)+" / "+str(sim.cells.size()),Color("#95dba7")]]:
  text(Vector2(42,y),row[0],14,Color("#e9ddbc"))
  text(Vector2(218,y),row[1],16,row[2])
  y+=26
func source_caption(lane,wave,fresh=false):
 var count=0
 for entry in wave:
  if entry.lane==lane:count+=entry.count
 return "● SOURCE %d · %s" % [lane+1,"NEW ★" if fresh else str(count)]
func source_marker(position,caption=""):
 var width=ceilf(game.symbol_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x)+16.0
 var center=Vector2(720,450)
 var direction=(position-center).normalized()
 if direction.is_zero_approx():direction=Vector2.RIGHT
 # The visor shader measures radius in viewport heights (1440 x 900).
 var radius=game.visor_radius*900.0
 var limit=radius-10.0
 if absf(direction.x)>0.001:limit=minf(limit,700.0/absf(direction.x))
 if direction.y< -0.001:limit=minf(limit,360.0/-direction.y)
 if direction.y>0.001:limit=minf(limit,280.0/direction.y)
 var outside=position.distance_to(center)>limit
 var tip=center+direction*limit
 var label_center=tip-direction*(width*0.5+18.0) if outside else position+Vector2(0,-63)
 var pos=label_center-Vector2(width*0.5,12)
 pos.x=clampf(pos.x,12,1428-width)
 pos.y=clampf(pos.y,80,700)
 return {"rect":Rect2(pos,Vector2(width,24)),"tip":tip,"direction":direction,"outside":outside}
func source_obstacles():
 var blocked=[Rect2(12,8,64,64),Rect2(460,4,520,72),Rect2(1350,285,90,380),Rect2(0,720,1440,180)]
 for panel in [note,forecast,cell_block,virus_block,game.focus_cells_button,game.lab_tools.debug_panel,game.lab_tools.gym_panel]:
  if is_instance_valid(panel) and panel.is_visible_in_tree():blocked.append(panel.get_global_rect().grow(8))
 return blocked
func marker_clear(marker,blocked):
 var rect=marker.rect.grow(5)
 if not Rect2(12,80,1416,630).encloses(rect):return false
 for obstacle in blocked:
  if rect.intersects(obstacle):return false
  if marker.outside and Rect2(marker.tip-Vector2(10,10),Vector2(20,20)).intersects(obstacle):return false
  if marker.outside:
   var corners=[obstacle.position,Vector2(obstacle.end.x,obstacle.position.y),obstacle.end,Vector2(obstacle.position.x,obstacle.end.y)]
   for edge in range(4):
    if Geometry2D.segment_intersects_segment(marker.rect.get_center(),marker.tip,corners[edge],corners[(edge+1)%4])!=null:return false
 return true
func place_source_marker(position,caption,blocked):
 var base=source_marker(position,caption)
 if marker_clear(base,blocked):return base
 for step in range(1,91):
  for sign_value in [-1,1]:
   var candidate=base.duplicate()
   if base.outside:
    var bearing=(position-Vector2(720,450)).rotated(step*0.035*sign_value)
    candidate=source_marker(Vector2(720,450)+bearing.normalized()*100000,caption)
    candidate.direction=(position-candidate.tip).normalized()
   else:
    var column=[0,-1,1,-2,2][(step-1)%5]
    var row=int((step-1)/5)+1
    candidate.rect=Rect2(base.rect.position+Vector2(column*(base.rect.size.x+12),row*34*sign_value),base.rect.size)
   if marker_clear(candidate,blocked):return candidate
 for y in range(90,680,34):
  for x in range(24,1300,24):
   var candidate=base.duplicate()
   candidate.rect=Rect2(Vector2(x,y),base.rect.size)
   candidate.outside=false
   if marker_clear(candidate,blocked):return candidate
 return base
func source_layout(wave):
 var result={}
 var blocked=source_obstacles()
 var ordered=lanes(wave)
 ordered.sort()
 for lane in ordered:
  if not game.view.sources.states.has(lane):continue
  var position=game.view.to_global(game.view.sources.states[lane].p)
  var fresh=game.view.staging=="warning" and lane not in lanes(game.sim.wave)
  var marker=place_source_marker(position,source_caption(lane,wave,fresh),blocked)
  result[lane]=marker
  blocked.append(marker.rect.grow(6))
  if marker.outside:blocked.append(Rect2(marker.tip-Vector2(12,12),Vector2(24,24)))
 return result
func clipped_source_segment(a:Vector2,b:Vector2,blocked:Array):
 # Clip the centerline inside the optical circle, leaving room for stroke + AA.
 var direction=b-a
 var relative=a-Vector2(720,450)
 var radius=maxf(0.0,game.visor_radius*900.0-2.0)
 var aa=direction.length_squared()
 if aa<0.000001:return []
 var bb=2.0*relative.dot(direction)
 var cc=relative.length_squared()-radius*radius
 var discriminant=bb*bb-4.0*aa*cc
 if discriminant<0:return []
 var low=maxf(0.0,(-bb-sqrt(discriminant))/(2.0*aa))
 var high=minf(1.0,(-bb+sqrt(discriminant))/(2.0*aa))
 if low>=high:return []
 var intervals=[Vector2(low,high)]
 for obstacle in blocked:
  var rect:Rect2=obstacle.grow(2)
  var enter=0.0
  var leave=1.0
  for axis in range(2):
   if absf(direction[axis])<0.000001:
    if a[axis]<rect.position[axis] or a[axis]>rect.end[axis]:leave=-1.0
   else:
    var first=(rect.position[axis]-a[axis])/direction[axis]
    var last=(rect.end[axis]-a[axis])/direction[axis]
    enter=maxf(enter,minf(first,last))
    leave=minf(leave,maxf(first,last))
  if enter>=leave:continue
  var remaining=[]
  for interval in intervals:
   if leave<=interval.x or enter>=interval.y:remaining.append(interval)
   else:
    if enter>interval.x:remaining.append(Vector2(interval.x,enter))
    if leave<interval.y:remaining.append(Vector2(leave,interval.y))
  intervals=remaining
  if intervals.is_empty():break
 var pieces=[]
 for interval in intervals:pieces.append(PackedVector2Array([a+direction*interval.x,a+direction*interval.y]))
 return pieces
func draw_source_labels():
 var wave=game.preview_wave if game.view.staging=="warning" else game.sim.wave
 var layout=source_layout(wave)
 var blocked=source_obstacles()
 for item in layout.values():blocked.append(item.rect.grow(3))
 for lane in lanes(wave):
  if not game.view.sources.states.has(lane):continue
  var position=game.view.to_global(game.view.sources.states[lane].p)
  var fresh=game.view.staging=="warning" and lane not in lanes(game.sim.wave)
  var caption=source_caption(lane,wave,fresh)
  var marker=layout[lane]
  var pos=marker.rect.position
  var color=GOLD if fresh else Color("#c25874")
  if game.field_new:
   var radius=66*game.view.scale.x
   for segment in range(24):
    for step in range(7):
     var start=segment*TAU/24+TAU/40*step/7.0
     var end=segment*TAU/24+TAU/40*(step+1)/7.0
     for piece in clipped_source_segment(position+Vector2.from_angle(start)*radius,position+Vector2.from_angle(end)*radius,blocked):
      draw_line(piece[0],piece[1],color,1.5,true)
  if marker.outside:
   var direction=marker.direction
   var side=direction.orthogonal()*7.0
   draw_line(marker.rect.get_center(),marker.tip-direction*10.0,color,2.0,true)
   draw_colored_polygon(PackedVector2Array([marker.tip,marker.tip-direction*15.0+side,marker.tip-direction*15.0-side]),color)
  box(marker.rect,DARK,color)
  text(pos+Vector2(8,16),caption,10,color.lightened(0.3))
func source_click(world):
 if game.sim.phase!="shop":return false
 var layout=source_layout(game.sim.wave)
 var pointer=game.view.to_global(world)
 # Labels take priority over nearby source bodies, especially in dense clusters.
 for pass_index in range(2):
  for lane in layout:
   var marker=layout[lane]
   var hit=marker.rect.has_point(pointer) or (marker.outside and pointer.distance_to(marker.tip)<18)
   if (pass_index==0 and hit) or (pass_index==1 and game.view.sources.states[lane].p.distance_to(world)<70):
    for entry in game.sim.wave:
     if entry.lane==lane:
      select_virus(entry.type,lane)
      return true
 return false

func draw_alert():
 var signal_data=game.view.attention.active
 if signal_data.is_empty():return
 var colors={"loss":Color("#d52e50"),"danger":Color("#e48140"),"link":Color("#d7b661"),"cleared":Color("#72c69d")}
 var color=colors.get(signal_data.kind,RED)
 color.a=(1.0-signal_data.age)*0.65*game.flash_intensity
 var width=4.0+signal_data.priority*1.5
 # Corner brackets for loss, long edges for danger, broken edges for bond, short pulse for clear.
 var extent={"loss":200.0,"danger":420.0,"link":90.0,"cleared":55.0}.get(signal_data.kind,90.0)
 for corner in [Vector2(4,4),Vector2(1436,4),Vector2(4,896),Vector2(1436,896)]:
  var direction=Vector2(1 if corner.x<720 else -1,1 if corner.y<450 else -1)
  draw_line(corner,corner+Vector2(extent*direction.x,0),color,width,true)
  draw_line(corner,corner+Vector2(0,extent*direction.y),color,width,true)
