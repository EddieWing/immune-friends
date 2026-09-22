extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate()
 scene.settings_path="user://cell_tuner_test.cfg"
 scene.save_path="user://cell_tuner_test_run.json"
 DirAccess.remove_absolute(scene.settings_path)
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.main_menu.hide()
 scene.modal.hide()
 var tuner=scene.cell_tuner
 var cell=scene.sim.make_cell("seeker",Vector2(200,0))
 scene.sim.cells.append(cell)
 var key=InputEventKey.new()
 key.keycode=KEY_T
 key.shift_pressed=true
 key.pressed=true
 scene._input(key)
 check(tuner.enabled,"Shift+T enables cell editor")
 check(tuner.inspect_at(cell.p) and scene.modal.visible,"Single click target opens editor and description")
 tuner.fields.hp.value=7
 tuner.fields.range.value=65
 tuner.submit(false)
 check(cell.hp==7 and scene.sim.catalog.seeker.range==65,"Test applies stats immediately")
 check(not scene.settings.has_section("cell_tuning"),"Test does not persist game settings")
 check(not scene.sim.tuning.seeker.has("interval"),"Untouched fields retain special ability rules")
 tuner.submit(false)
 check(cell.hp==7,"Repeated Test does not accumulate HP")
 scene.save_run()
 var original_hp=scene.sim.catalog.seeker.hp
 scene.sim.apply_tuning("seeker",{"hp":2})
 scene.load_run()
 check(scene.sim.cells[0].hp==2,"Loading a Test checkpoint restores current HP balance")
 scene.sim.apply_tuning("seeker",{"hp":original_hp})
 tuner.open("seeker")
 scene.sim.phase="battle"
 var elapsed=scene.sim.elapsed
 scene.advance_simulation(1)
 check(scene.sim.elapsed==elapsed,"Editor pauses battle")
 tuner.open("wall")
 tuner.fields.hp.value=9
 tuner.submit(true)
 var disk=ConfigFile.new()
 check(disk.load(scene.settings_path)==OK,"Save writes device settings")
 var saved=disk.get_value("cell_tuning","types",{})
 check(saved.has("wall") and not saved.has("seeker"),"Save excludes other types tested only in session")
 var fresh=preload("res://scripts/simulation.gd").new()
 fresh.reset(42,12)
 tuner.apply_to(fresh)
 check(fresh.make_cell("seeker",Vector2.ZERO).hp==7,"Session settings apply to fresh simulation")
 var owner=load("res://main.tscn").instantiate()
 owner.settings_path=scene.settings_path
 owner.save_path="user://cell_tuner_second_run.json"
 root.add_child(owner)
 await process_frame
 owner.set_process(false)
 check(owner.sim.catalog.wall.hp==9 and owner.sim.catalog.seeker.hp==2,"Restart loads only saved types")
 tuner.open("__core")
 tuner.fields["blood_drift/speed"].value=12
 tuner.submit(false)
 check(scene.sim.rules.blood_drift.speed==12,"Core rule editor applies shared settings")
 tuner.open("virus:seeker")
 tuner.fields.hp.value=8
 tuner.fields.speed_multiplier.value=2
 tuner.submit(false)
 scene.sim.spawn_virus({"type":"seeker","lane":0})
 check(scene.sim.viruses.back().hp==8 and scene.sim.tuning["virus:seeker"].speed_multiplier==2,"Future viruses use edited type settings")
 scene._input(key)
 check(not tuner.enabled and not scene.modal.visible,"Shift+T disables mode and closes editor")
 owner.queue_free()
 scene.queue_free()
 await process_frame
 DirAccess.remove_absolute("user://cell_tuner_test.cfg")
 DirAccess.remove_absolute("user://cell_tuner_test_run.json")
 quit(1 if failures else 0)
