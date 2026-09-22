extends RefCounted
var game
var enabled=false
var session={}
var fields={}
var original_values={}
var current_key=""
var status: Label
const CELL_FIELDS={"hp":[1,10000,1,"Base HP per copy; existing cells retain damage and permanent bonuses."],"range":[0,1000,0.5,"Base ability range in microns; bonuses are added on top."],"speed":[0,1000,0.5,"Base movement speed; movement and network multipliers still apply."],"interval":[0,120,0.01,"Seconds between abilities. Overrides elite and Gatling cooldown rules while active."]}
const VIRUS_FIELDS={"hp":[1,10000,1,"Starting HP; applies to this virus type, including future spawns."],"speed_multiplier":[0,10,0.05,"Multiplies travel speed after emergence, including Jumper leaps."]}
func initialize(owner):
 game=owner
 session=game.settings.get_value("cell_tuning","types",{}).duplicate(true)
 apply_to(game.sim)
func apply_to(sim):
 for key in session: sim.apply_tuning(key,session[key])
func toggle():
 enabled=not enabled
 game.cancel_placement()
 game.gym_tool={}
 game.dragging=false
 game.rotating=false
 game.dragging_blood=-1
 game.sim.release_blood()
 if not enabled and is_instance_valid(game.modal_panel) and game.modal_panel.get_meta("cell_tuner",false): game.modal.hide()
 game.sim.last_message="CELL DEBUG ON · Click a cell · Shift+T to exit" if enabled else "Cell debug off"
 game.refresh()
func inspect_at(world):
 for cell in game.sim.cells:
  if cell.alive and game.sim.contains_cell(cell,world,6):
   open(cell.key)
   return true
 for core in game.sim.blood:
  if core.alive and core.p.distance_to(world)<16:
   open("__core")
   return true
 for virus in game.sim.viruses:
  if virus.alive and virus.p.distance_to(world)<20:
   open("virus:"+virus.type)
   return true
 return false
func schema(key):
 if key=="__core":
  var result={}
  for group in ["blood_drift","blood_elasticity","blood_faces"]:
   for field in game.sim.rules[group]:
    result[group+"/"+field]=[0.01 if field in ["slow_radius","look_smoothing"] else 0,1000,0.01,"Shared by all Core cells. "+group.trim_prefix("blood_")+": "+field.replace("_"," ")]
  return result
 return VIRUS_FIELDS if key.begins_with("virus:") else CELL_FIELDS
func values(key):
 if key=="__core":
  var result={}
  for path in schema(key):
   var parts=path.split("/")
   result[path]=game.sim.rules[parts[0]][parts[1]]
  return result
 if key.begins_with("virus:"):
  var result={"hp":2 if key=="virus:seeker" else 1,"speed_multiplier":1.0}
  result.merge(session.get(key,{}),true)
  return result
 return game.sim.catalog[key]
func open(key):
 current_key=key
 fields.clear()
 var title="Core cells" if key=="__core" else (key.trim_prefix("virus:").capitalize()+" virus" if key.begins_with("virus:") else game.sim.catalog[key].name)
 var col=game.clear_modal("DEBUG · "+title,"Edit this type · Test: current session · Save: this device/browser")
 game.modal_panel.set_meta("pause_for_settings",true)
 game.modal_panel.set_meta("cell_tuner",true)
 game.modal_panel.add_theme_stylebox_override("panel",game.style(Color("#101418"),8,Color("#ba77ff")))
 var theme=game.ui.theme.duplicate()
 theme.default_font=preload("res://assets/fonts/CascadiaMono.ttf")
 for kind in ["Label","RichTextLabel"]: theme.set_color("font_color",kind,Color("#edf4ff"))
 game.modal_panel.theme=theme
 for child in col.get_children():
  if child is Label: child.add_theme_color_override("font_color",Color("#edf4ff"))
 var description=Label.new()
 description.text="Protected cells. Drift, elastic hands and facial reactions are shared settings." if key=="__core" else (game.virus_description(key.trim_prefix("virus:")) if key.begins_with("virus:") else game.sim.catalog[key].description)
 description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 col.add_child(description)
 var scroll=ScrollContainer.new()
 scroll.custom_minimum_size=Vector2(500,300)
 col.add_child(scroll)
 var grid=GridContainer.new()
 grid.columns=2
 grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(grid)
 var data=values(key)
 original_values=data.duplicate(true)
 for field in schema(key):
  var spec=schema(key)[field]
  var label=Label.new()
  label.text=field.replace("blood_","").replace("_"," ").capitalize()
  label.tooltip_text=spec[3]
  label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  grid.add_child(label)
  var spin=SpinBox.new()
  spin.min_value=spec[0]
  spin.max_value=spec[1]
  spin.step=spec[2]
  spin.value=data[field]
  spin.tooltip_text=spec[3]
  spin.custom_minimum_size.x=150
  grid.add_child(spin)
  fields[field]=spin
 status=Label.new()
 status.custom_minimum_size.y=44
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 status.text="Battle pauses while this editor is open. Changes affect all cells of this type."
 col.add_child(status)
 var actions=HBoxContainer.new()
 col.add_child(actions)
 game.button(actions,"Test",func(): submit(false),Vector2(145,40))
 game.button(actions,"Save",func(): submit(true),Vector2(145,40))
 game.button(actions,"Close",func(): game.modal.hide(),Vector2(145,40))
 game.button(col,"Export saved",export_saved)
func export_saved():
 var payload={"format":"microcosm-cell-tuning","version":1,"types":game.settings.get_value("cell_tuning","types",{}).duplicate(true)}
 var content=JSON.stringify(payload,"  ")
 if OS.has_feature("web"):
  JavaScriptBridge.download_buffer(content.to_utf8_buffer(),"microcosm-cell-tuning.json","application/json")
  status.text="Saved settings exported. Attach the JSON file when requesting publication."
 else:
  var path="user://microcosm-cell-tuning.json"
  var file=FileAccess.open(path,FileAccess.WRITE)
  if file:
   file.store_string(content)
   file.close()
   status.text="Exported to "+ProjectSettings.globalize_path(path)
   OS.shell_open(ProjectSettings.globalize_path("user://"))
  else: status.text="Export failed: "+str(FileAccess.get_open_error())
func submit(persist):
 var data=session.get(current_key,{}).duplicate(true)
 for field in fields:
  if fields[field].get_line_edit().has_focus(): fields[field].apply()
  if not is_equal_approx(float(original_values[field]),fields[field].value): data[field]=fields[field].value
 if persist:
  var saved=game.settings.get_value("cell_tuning","types",{}).duplicate(true)
  saved[current_key]=data.duplicate(true)
  var previous=game.settings.get_value("cell_tuning","types",{}).duplicate(true)
  game.settings.set_value("cell_tuning","types",saved)
  var error=game.settings.save(game.settings_path)
  if error!=OK:
   game.settings.set_value("cell_tuning","types",previous)
   status.text="Save failed (%s). Changes have not been applied." % error
   return
 session[current_key]=data.duplicate(true)
 game.sim.apply_tuning(current_key,data)
 if not game.gym_return.is_empty(): game.gym_return.sim.apply_tuning(current_key,data)
 status.text="Saved for this device/browser. Close to resume." if persist else "Testing for this session only. Close to resume."
 game.refresh()
