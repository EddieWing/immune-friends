extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():call_deferred("run")
func run():
	for mode in range(4):
		var s=Sim.new();s.training_mode=mode;s.reset(42,12)
		check(s.blood.size()==[14,30,30,30][mode] and s.target_rounds==[6,10,12,12][mode],"MC-034: mode sets starting Core and length %d"%mode)
		var keys=s.available_cell_keys()
		check(keys.has("zapper")== (mode==3) and keys.has("bank")== (mode==3),"MC-034: electric/money packs mode %d"%mode)
		check(keys.has("tag_dropper")== (mode>=2),"MC-034: tag pack mode %d"%mode)
	var scene=load("res://main.tscn").instantiate()
	scene.settings_path="user://mc034-test.cfg";scene.save_path="user://mc034-test.json";root.add_child(scene);await process_frame;scene.set_process(false)
	scene.sim.training_mode=1;scene.sim.reset(42,12);scene.save_run();scene.sim.training_mode=3;scene.load_run()
	check(scene.sim.training_mode==1 and scene.sim.target_rounds==10,"MC-034: save restores its mode independently of settings")
	var data=JSON.parse_string(FileAccess.get_file_as_string(scene.save_path));data.erase("training_mode");data.rounds=12;data.experimental=false
	var file=FileAccess.open(scene.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close();scene.load_run()
	check(scene.sim.training_mode==-1 and scene.sim.target_rounds==12 and not scene.sim.experimental,"MC-034: old save retains legacy limits/catalogue")
	quit(errors)

