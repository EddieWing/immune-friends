extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Save=preload("res://scripts/preparation_save.gd")
var failures=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:failures+=1
func same(a,b):
	var x=JSON.stringify(Save.encode(a));var y=JSON.stringify(Save.encode(b))
	if x!=y:
		for i in range(mini(x.length(),y.length())):
			if x[i]!=y[i]:
				print("DIFF ",x.substr(maxi(0,i-40),160)," VS ",y.substr(maxi(0,i-40),160));break
	return x==y
func _initialize():call_deferred("run")
func run():
	var s=Sim.new();s.reset(123,12);s.round_no=7;s.make_wave()
	var c=s.make_cell("tag_drag",Vector2(45,70));c["drag_triggers"]=1;c.max_hp=17;c.hp=13;c.rank=3;c["copies"]=4;c.sale=9
	s.cells=[c];s.money=3;s.max_funds=10;s.frozen=true;s.reward_choices=[["wildcard","bank"]];s.rewards=["wildcard"];s.selected_rewards=["bank"]
	s.blood[0]["hp"]=0.5;s.blood[0].alive=false;s.blood_velocity[s.blood[1].id]=Vector2(2,3)
	s.particles=[{"kind":"tag","p":Vector2(4,5),"v":Vector2(1,2),"life":3.2,"r":7.0,"owner":c.id,"setup":true}]
	var raw=JSON.parse_string(JSON.stringify(Save.capture(s),"",true,true))
	var checked=Save.inspect(raw,s)
	check(not checked.has("error"),"complete state validates")
	if checked.has("error"):quit(1);return
	var restored=Sim.new();Save.restore(restored,checked)
	check(same(restored.cells,s.cells) and same(restored.blood,s.blood),"cell permanent fields and complete Core state roundtrip")
	check(same(restored.particles,s.particles) and same(restored.blood_velocity,s.blood_velocity),"preparation resources and Core velocities preserved")
	check(same(restored.wave,s.wave) and same(restored.source_emitters,s.source_emitters),"exact wave geometry and timing preserved")
	check(restored.money==3 and restored.max_funds==10 and restored.reward_choices==s.reward_choices and restored.frozen,"no repeated income or reward")
	s.begin_battle();restored.begin_battle()
	check(s.spawn_queue==restored.spawn_queue and s.rng.state==restored.rng.state,"identical next battle releases and RNG")
	for i in range(180):s.update(1.0/60.0);restored.update(1.0/60.0)
	check(same(s.cells,restored.cells) and same(s.viruses,restored.viruses) and same(s.blood,restored.blood),"three seconds of simulation reproduce exactly")
	var invalid=raw.duplicate(true);invalid.version=999
	check(Save.inspect(invalid,restored).has("error"),"future version rejected")
	invalid=raw.duplicate(true);invalid.state.cells[0].key="missing_cell"
	check(Save.inspect(invalid,restored).has("error"),"unknown cell rejected before mutation")
	var scene=load("res://main.tscn").instantiate();scene.save_path="user://test_mc036_invalid.json";root.add_child(scene);await process_frame
	var file=FileAccess.open(scene.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(invalid));file.close()
	var saved_text=FileAccess.get_file_as_string(scene.save_path)
	var old=Save.capture(scene.sim);scene.load_run()
	check(Save.capture(scene.sim)==old and scene.modal.visible,"invalid load preserves current run and shows a choice")
	check(FileAccess.get_file_as_string(scene.save_path)==saved_text,"invalid saved file is not overwritten")
	DirAccess.remove_absolute(scene.save_path);scene.queue_free();await process_frame
	print("RESULT: preparation save, %d failures"%failures);quit(1 if failures else 0)

