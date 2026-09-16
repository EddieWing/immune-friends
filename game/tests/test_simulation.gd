extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
var checks=0

func check(ok, message):
	checks+=1
	if not ok:
		errors+=1
		printerr("FAIL: "+message)
	else: print("PASS: "+message)

func _initialize():
	call_deferred("run")

func add(s,key,p=Vector2.ZERO):
	var c=s.make_cell(key,p)
	s.cells.append(c)
	return c

func run():
	var s=Sim.new()
	s.reset(42,12)
	check(s.catalog.size()>=31 and s.catalog.has("mortar") and s.catalog.has("tag_drag"),"original catalogue plus production cells")
	check(s.money==4 and s.capacity()==4,"starting economy")
	s.offers=["wall","wall","wall"]
	check(s.purchase(0,Vector2(150,0)),"purchase deducts")
	check(s.money==2 and s.cells.size()==1,"purchase state")
	var wall=s.cells[0]
	s.purchase(0,Vector2(150,0))
	check(s.cells.size()==1 and wall.hp==6 and wall.rank==2,"double merge")
	s.money=2
	s.purchase(0,wall.p)
	check(wall.rank==3 and wall.hp==9 and s.reward_choices.size()==1,"triple and reward")
	s.choose_reward(0)
	check(s.rewards.size()==1 and s.reward_choices.is_empty(),"reward chosen")
	s.reset()
	s.frozen=true
	var offers=s.offers.duplicate()
	s.phase="recap"
	s.money=7
	s.next_round()
	check(s.money==5 and s.offers==offers,"expired money and frozen shop")
	s.money=3
	s.buy_xp()
	check(s.tier==2 and s.capacity()==7 and s.money==0,"XP and capacity")
	s.reset()
	var bank=add(s,"bank",Vector2(300,200))
	s.phase="recap"
	s.next_round()
	check(bank.sale==2,"bank sale growth")
	var money=s.money
	s.sell(bank)
	check(s.money==money+2 and s.cells.is_empty(),"bank sale realized")
	s.reset()
	var rw=add(s,"resonant_wall")
	s.offers=["bank"]
	s.purchase(0,Vector2(200,0))
	check(rw.hp==4,"resonant wall purchase buff")
	s.reset()
	var sw=add(s,"swapper")
	var wc=add(s,"wildcard",Vector2(50,0))
	s.merge(sw,wc)
	check(sw.hp==7 and sw.rank==2 and s.cells.size()==1,"wildcard HP sum")
	s.reset()
	var orb=add(s,"orbiter",Vector2(170,0))
	var guard=add(s,"bodyguard",Vector2(230,0))
	s.rebuild_links()
	check(s.links.size()==1,"automatic nearest bond")
	var initial=orb.p
	s.begin_battle()
	for i in range(180): s.update(1.0/60.0)
	check(orb.p.distance_to(initial)>40 and guard.p.distance_to(Vector2(230,0))>20,"mobile bonded pair")
	check(absf(orb.p.distance_to(guard.p)-60)<12,"bond length constraint")
	var before=orb.hp
	var gh=guard.hp
	s.damage_cell(orb,1)
	check(orb.hp==before and guard.hp==gh-1,"network redirects full damage")
	s.reset()
	var bomb=add(s,"bomb",Vector2.ZERO)
	var victim=add(s,"wall",Vector2(25,0))
	s.damage_cell(bomb,1)
	check(victim.hp==1 and not bomb.alive,"bomb friendly fire and death")
	s.reset()
	var bandage=add(s,"bandage")
	var patient=add(s,"wall",Vector2(35,0))
	s.damage_cell(bandage,1)
	check(patient.hp==4,"bandage death heal")
	s.reset()
	var swapper=add(s,"swapper")
	var drop=add(s,"tag_dropper",Vector2(60,0))
	drop.max_hp=12
	drop.hp=12
	s.rebuild_links()
	s.phase="recap"
	s.next_round()
	check(swapper.hp==12 and drop.hp==3,"provisional swap timing")
	# Exercise every behavior in a dense arena and ensure complete termination.
	s.reset(42,12)
	for key in s.catalog:
		add(s,key,Vector2(s.rng.randf_range(-180,180),s.rng.randf_range(-100,100)))
	s.round_no=8
	s.make_wave()
	s.begin_battle()
	for i in range(60*185):
		s.update(1.0/60.0)
		if s.phase!="battle": break
	check(s.phase!="battle","all abilities stress battle terminates")
	# Empty army must lose and a clear final wave must win.
	s.reset()
	s.round_no=12
	s.make_wave()
	s.begin_battle()
	for i in range(60*120):
		s.update(1.0/60.0)
		if s.phase!="battle": break
	check(s.phase=="lose","terminal defeat")
	s.reset()
	s.round_no=12
	s.begin_battle()
	s.spawn_queue.clear()
	s.update(0.02)
	check(s.phase=="win","terminal victory")
	print("RESULT: %d checks, %d failures" % [checks,errors])
	quit(1 if errors else 0)
