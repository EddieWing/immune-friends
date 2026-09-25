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
 check(scene.ui_new and scene.field_new and scene.visor_new,"New styles default independently")
 check(hud.visible and not scene.dock.visible and hud.note.visible,"New preparation HUD replaces classic controls")
 scene.sim.tier=5
 scene.sim.roll_shop(false)
 scene.sim.rewards=["accelerator","generator","bandage"]
 scene.refresh()
 hud._process(0.1)
 await process_frame
 check(hud.offers.get_child_count()==10 and hud.shelf.size.x==728,"All offers and rewards remain inside fixed scrolling shelf")
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
 button.pressed.emit()
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
