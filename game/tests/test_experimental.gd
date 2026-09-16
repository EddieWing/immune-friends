extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=0
func check(ok,message):
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures+=1
func add(s,key,p):
	var c=s.make_cell(key,p)
	s.cells.append(c)
	return c
func food(s,c,kind,count):
	for i in range(count): s.particles.append({"kind":kind,"p":c.p,"v":Vector2.ZERO,"life":10.0,"r":5.0,"owner":-1})
func _initialize(): call_deferred("run")
func run():
	var s=Sim.new()
	s.reset()
	check(not s.experimental and s.available_cell_keys().size()==33 and not s.available_virus_keys().has("pusher"),"Experimental OFF by default")
	s.tier=5
	s.money=1000
	var clean=true
	for i in range(80):
		s.roll_shop(false)
		s.queue_reward()
		for key in s.offers+s.reward_choices.back(): clean=clean and not s.catalog[key].get("experimental",false)
	check(clean,"Shop and rewards exclude experimental content")
	s.offers=["gatling"]
	check(not s.purchase(0,Vector2.ZERO),"Disabled experimental purchase rejected")
	s.experimental=true
	s.reset()
	check(s.available_cell_keys().size()==41 and s.available_virus_keys().has("pusher"),"Enabled catalogue exposes all experiments")
	s.gym_mode=true
	var factory=add(s,"seeker_factory",Vector2(300,0))
	var gun=add(s,"turret",Vector2(200,0))
	s.begin_battle()
	s.spawn_queue.clear()
	check(s.experiments.feed_target(s,gun)==factory,"Friendly shooter selects hungry factory")
	food(s,factory,"food",1)
	food(s,factory,"bullet",2)
	s.update(0.016)
	check(s.cells.any(func(c):return c.key=="seeker" and c.get("temporary",false)),"Factory recipe produces a temporary Seeker")
	var kinetic=add(s,"kinetic_generator",Vector2(-300,0))
	s.experiments.tick(s,kinetic,0.1)
	kinetic.p.x+=36
	s.experiments.tick(s,kinetic,0.1)
	check(kinetic.charge==1,"Twelve microns generate one charge")
	var magnet=add(s,"electromagnet",kinetic.p+Vector2(30,0))
	s.experiments.tick(s,magnet,0.1)
	check(magnet.charge==1 and kinetic.charge==0 and s.range_of(magnet)>60,"Electromagnet transfers charge and grows field")
	var wall=add(s,"electric_wall",Vector2(0,-200))
	add(s,"wall",Vector2(20,-200))
	s.experiments.tick(s,wall,0.1)
	check(wall.charge==1,"Electric Wall charges on allied contact")
	var hungry=add(s,"hungry_bomb",Vector2(0,200))
	food(s,hungry,"food",2)
	s.experiments.tick(s,hungry,0.1)
	check(s.range_of(hungry)>30,"Hungry Bomb grows by eating Virus Protein")
	var proof=add(s,"tag_proof",Vector2(500,200))
	s.spawn_virus({"type":"basic","lane":0})
	var v=s.viruses.back()
	v.tag=1.0
	v.jump=false
	s.damage_cell(proof,1,false,{"kind":"virus","id":v.id})
	check(proof.hp==6,"Tagged-virus contact cannot damage Tag-Proof")
	v.tag=0
	s.damage_cell(proof,1,false,{"kind":"virus","id":v.id})
	check(proof.hp==5,"Untagged-virus damage remains active")
	var gatling=add(s,"gatling",Vector2(500,-200))
	s.damage_virus(v,99,{"owner":gatling.id,"cause":"bullet"})
	check(s.interval_of(gatling)==1.75,"Gatling kill reduces cooldown by 0.25")
	s.spawn_virus({"type":"pusher","lane":0})
	v=s.viruses.back()
	v.p=proof.p-Vector2(30,0)
	v.jump=false
	var before=proof.p
	s.damage_virus(v,99)
	check(proof.p.distance_to(before)>0,"Pusher Virus death moves nearby immune cell")
	var bond=add(s,"kinetic_bond",Vector2(-450,-220))
	var passenger=add(s,"wall",Vector2(-400,-220))
	s.rebuild_links()
	s.experiments.tick(s,passenger,0.1)
	passenger.p.x+=36
	s.experiments.tick(s,passenger,0.1)
	check(passenger.hp>passenger.max_hp,"Kinetic Bond grants movement health")
	# UI/settings/save round trip must retain a run flag independently of preferences.
	var scene=load("res://main.tscn").instantiate()
	scene.save_path="user://experimental-test-save.json"
	scene.settings_path="user://experimental-test-settings.cfg"
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.settings.set_value("tutorial","disabled",true)
	scene.show_settings()
	var toggle=scene.modal.find_child("ExperimentalToggle",true,false)
	check(toggle!=null and toggle.text=="Turn on experimental","Settings exposes named toggle")
	toggle.button_pressed=true
	scene.new_run(12)
	check(scene.sim.experimental,"New run uses toggle")
	var dropper=add(scene.sim,"tag_drag",Vector2(100,200))
	scene.sim.proteins.drag(scene.sim,dropper,Vector2(190,200))
	var survivor=add(scene.sim,"survivor_bomb",Vector2(300,200))
	survivor["radius_growth"]=16
	scene.save_run()
	scene.settings.set_value("gameplay","experimental",false)
	scene.load_run()
	check(scene.sim.experimental,"Saved run retains experimental mode after preference OFF")
	check(scene.sim.particles.size()==2 and scene.sim.cells[0].tags==13,"Save restores laid tags and stock")
	check(scene.sim.cells[1].radius_growth==16,"Save restores Survivor growth")
	scene.new_run(12)
	check(not scene.sim.experimental and scene.sim.cells.is_empty(),"New normal run excludes previous experimental state")
	scene.settings.set_value("gameplay","experimental",true)
	scene.enter_gym()
	check(scene.sim.experimental and scene.lab_tools.cell_keys.size()==42 and scene.lab_tools.virus_keys.size()==8,"Gym refreshes experimental selectors")
	dropper=add(scene.sim,"tag_drag",Vector2(100,200))
	scene.sim.proteins.drag(scene.sim,dropper,Vector2(190,200))
	scene.gym_run()
	scene.gym_reset_setup()
	check(scene.sim.particles.size()==2 and scene.sim.cells[0].tags==13,"Gym reset restores preparation tags and inventory")
	scene.leave_gym()
	check(not scene.sim.experimental and scene.lab_tools.cell_keys.size()==34,"Leaving Gym restores normal run and selectors")
	scene.queue_free()
	await process_frame
	quit(failures)
