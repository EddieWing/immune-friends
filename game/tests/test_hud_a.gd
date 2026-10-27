extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://hud_a_test.cfg"
 scene.save_path="user://hud_a_test.json"
 DirAccess.remove_absolute(scene.settings_path)
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.main_menu.hide()
 scene.modal.hide()
 var hud=scene.hud_a
 hud._process(0.4)
 scene.visor_radius=0.54
 check(hud.clipped_source_segment(Vector2(1250,400),Vector2(1300,450),[]).is_empty(),"Source outline outside visor is hidden")
 var clipped=hud.clipped_source_segment(Vector2(1100,450),Vector2(1300,450),[])
 check(clipped.size()==1 and clipped[0][1].x<=1204.01,"Source outline crossing visor is clipped at optical boundary")
 var masked=hud.clipped_source_segment(Vector2(600,450),Vector2(800,450),[Rect2(650,400,100,100)])
 check(masked.size()==2 and masked[0][1].x<=648.01 and masked[1][0].x>=751.99,"UI removes middle of source outline with stroke padding")
 check(hud.clipped_source_segment(Vector2(680,450),Vector2(720,450),[Rect2(650,400,100,100)]).is_empty(),"Source outline beneath UI is hidden")
 for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
  var marker=hud.source_marker(Vector2(720,450)+direction*1500)
  check(marker.outside and marker.tip.distance_to(Vector2(720,450))<486,"Offscreen source pointer stays inside visor")
  check(Rect2(0,0,1440,900).encloses(marker.rect),"Source caption stays on screen")
  check(marker.direction.dot(direction)>0.99,"Source pointer preserves bearing")
 check(not hud.source_marker(Vector2(800,450)).outside,"Visible source keeps its local label")
 for position in [Vector2(1000,450),Vector2(2000,450),Vector2(-1000,450),Vector2(720,-1000),Vector2(720,1800)]:
  var blocked=hud.source_obstacles()
  for i in range(8):
   var marker=hud.place_source_marker(position+Vector2(i*2,i*2),"SOURCE %d - 12" % (i+1),blocked)
   check(hud.marker_clear(marker,blocked),"Clustered sources avoid UI and other markers")
   blocked.append(marker.rect.grow(6))
   if marker.outside:blocked.append(Rect2(marker.tip-Vector2(12,12),Vector2(24,24)))
 check(scene.ui_new and scene.field_new and scene.visor_new,"New styles default independently")
 check(hud.visible and not scene.dock.visible and hud.note.visible,"New preparation HUD replaces classic controls")
 scene.sim.tier=5
 scene.sim.roll_shop(false)
 scene.sim.rewards=["accelerator","generator","bandage"]
 scene.refresh()
 hud._process(0.1)
 await process_frame
 check(hud.offers.get_child_count()==9 and hud.shelf.size.x==728,"All offers and rewards remain inside fixed scrolling shelf")
 check(not hud.upgrade.visible,"Maximum tier hides upgrade")
 scene.sim.frozen=true
 scene.sim.money=10
 hud._process(0.1)
 check(not hud.refresh_button.disabled,"Freeze preserves existing refresh rules")
 var cell=scene.sim.make_cell("seeker",Vector2(140,0))
 scene.sim.cells.append(cell)
 hud.select_cell("seeker",cell)
 hud.select_virus("basic",0)
 hud._process(0.1)
 check(hud.cell_block.visible and hud.virus_block.visible,"Cell and virus files coexist")
 scene.start_battle()
 scene.launch_remaining=0
 hud._process(1)
 check(not hud.shelf.visible and hud.transport[0].visible and not hud.cell_block.visible and not hud.virus_block.visible,"Infection hides shelf and files and reveals transport")
 scene.sim.phase="recap"
 scene.sim.battle_income=3
 var money=scene.sim.money
 scene.show_recap()
 hud._process(0.1)
 for i in range(8):await process_frame
 check(Rect2(0,0,1440,900).encloses(hud.forecast.get_global_rect()),"Forecast panel fits viewport after dynamic layout")
 check(hud.forecast.visible and not scene.modal.visible and not hud.transport[0].visible,"Forecast is an undimmed reading panel")
 var budget=mini(scene.sim.round_no+4,10)+3
 var button=hud.forecast_rows.get_child(hud.forecast_rows.get_child_count()-1)
 check(str(budget) in button.text and scene.sim.money==money,"Forecast budget includes pending Mint without crediting early")
 scene.camera_requested=1.2
 scene.zoom_target=0.6
 scene.view.scale=Vector2.ONE*0.6
 button.pressed.emit()
 check(is_equal_approx(scene.zoom_target,1.5) and scene.shopping_in_focus(),"Preparation opens shop at close zoom after forecast overview")
 check(scene.sim.phase=="shop" and scene.sim.money==budget,"To preparation credits displayed budget once")
 scene.show_appearance()
 var picker=scene.modal.find_child("Appearance_hud",true,false)
 picker.item_selected.emit(1)
 hud._process(0.1)
 check(not scene.ui_new and scene.field_new and scene.visor_new and scene.dock.visible,"HUD can revert without changing field or visor")
 var config=ConfigFile.new()
 config.load(scene.settings_path)
 check(config.get_value("appearance","hud",true)==false,"Appearance selection persists")
 scene.queue_free()
 await process_frame
 DirAccess.remove_absolute("user://hud_a_test.cfg")
 DirAccess.remove_absolute("user://hud_a_test.json")
 quit(1 if failures else 0)
