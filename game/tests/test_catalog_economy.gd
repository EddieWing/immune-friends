extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=0
var checks=0
func check(ok,label):
	checks+=1
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func _initialize():
	call_deferred("run")
func run():
	var s=Sim.new()
	s.reset(92)
	check(s.money==4 and s.max_funds==4 and s.xp==1,"First shop income and XP")
	s.offers.remove_at(0)
	var frozen_offer=s.offers.duplicate()
	s.frozen=true
	s.money=99
	s.battle_income=2
	s.phase="recap"
	s.next_round()
	check(s.money==7 and s.max_funds==5 and s.battle_income==0,"New budget discards leftover and applies bonus once")
	check(s.offers==frozen_offer and not s.frozen and s.xp==2,"Freeze preserves remaining slots once")
	s.phase="recap"
	s.next_round()
	check(s.money==6 and s.xp==3 and s.tier==2 and s.offers.size()==4,"Automatic XP upgrades and next unfrozen shop redraws")
	s.reset()
	s.money=99
	s.offers=["wall"]
	s.buy_xp()
	check(s.xp==2 and s.offers==["wall"],"XP purchase without level does not refill")
	s.buy_xp()
	check(s.xp==3 and s.tier==2 and s.offers.size()==4 and s.offers[0]=="wall","Level purchase fills vacancies preserving existing cards")
	for i in range(14): s.buy_xp()
	check(s.tier==5 and s.xp==17 and s.capacity()==16 and not s.buy_xp(),"Cumulative XP reaches max at17")
	s.roll_shop(false)
	check(s.offers.size()==6,"Maximum market has six slots")
	s.max_funds=10
	s.battle_income=2
	s.phase="recap"
	s.next_round()
	check(s.next_budget()==10,"Budget preview consumes bonus only once")
	check(s.money==12 and s.max_funds==10 and s.xp==17,"Base income capped separately from bonus; max level XP stops")
	s.reset()
	s.phase="recap"; s.frozen=true; s.xp=2
	s.next_round()
	check(s.tier==2 and s.offers.size()==3,"Round level-up retains frozen offer without filling")
	s.experimental=true
	s.reset()
	s.tier=3
	var counts=[0,0,0]
	for i in range(20000): counts[int(s.catalog[s.draw_offer()].tier)-1]+=1
	check(absf(counts[0]/20000.0-.33)<.015 and absf(counts[1]/20000.0-.33)<.015 and absf(counts[2]/20000.0-.34)<.015,"Tier probabilities are33/33/34 independent of pool sizes")
	s.reward_choices=[["mint","radar"]]
	s.choose_reward(0)
	check(s.selected_rewards==["mint"] and s.rewards==["mint"],"Chosen reward enters offer and future replacement history")
	var money=s.money
	check(s.purchase(0,Vector2(300,0),true) and s.money==money,"Reward redemption is free")
	var count=0
	for i in range(20000):
		if s.draw_offer()=="mint": count+=1
	check(count>140 and count<270,"Selected rewards replace approximately1 percent of offers")
	var regen=s.make_cell("regen",Vector2.ZERO);regen.rank=3
	check(s.interval_of(regen)==2.5 and s.constant_of(regen,"healAmount")==1,"Elite cooldown override inherits ordinary constant")
	var bandage=s.make_cell("bandage",Vector2.ZERO);bandage.rank=3
	check(s.range_of(bandage)==25*s.rules.scale and s.constant_of(bandage,"healAmount")==2,"Elite Bandage stats and constants")
	var survivor=s.make_cell("survivor_bomb",Vector2.ZERO);survivor.rank=3
	check(s.range_of(survivor)==12*s.rules.scale,"Unspecified elite radius inherits base rather than invented override")
	var turret=s.make_cell("turret",Vector2.ZERO);turret.rank=3
	check(s.interval_of(turret)==1,"Elite Turret cooldown")
	s.apply_tuning("turret",{"interval":4.0})
	check(s.interval_of(turret)==4,"Explicit tuner remains authoritative")
	s.reset()
	var bank=s.make_cell("bank",Vector2.ZERO);bank.rank=3;s.cells=[bank]
	s.phase="recap";s.next_round()
	check(bank.sale==3,"Elite Bank adds2 to ordinary sale value")
	var second_bank=s.make_cell("bank",Vector2(100,0));second_bank.sale=4
	var first_bank=s.make_cell("bank",Vector2(150,0));first_bank.sale=2
	s.cells.append_array([first_bank,second_bank])
	s.merge(first_bank,second_bank)
	check(first_bank.sale==5,"Merging retains both sale modifiers with one base coin")
	var bank_money=s.money;s.sell(bank)
	check(s.money==bank_money+3,"Sale pays base1 plus accumulated modifier")
	var mint=s.make_cell("mint",Vector2(300,0));mint.rank=3;s.cells=[mint]
	s.particles=[]
	for i in range(5): s.particles.append({"kind":"food","p":mint.p,"life":1.0})
	s.proteins.tick(s,mint,0)
	check(s.battle_income==2 and mint.food==0,"Existing Mint consumption uses catalog5 food and elite2 income")
	check(s.catalog.size()==41 and s.rules.contact_damage==1 and s.rules.bond_stiffness>0 and s.rules.max_battle_seconds==180,"No new cells, HP damage, rigid bonds or lifetime reconstruction")
	var scene=load("res://main.tscn").instantiate()
	scene.settings_path="user://catalog_economy_test.cfg"
	scene.save_path="user://catalog_economy_test.json"
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.sim.reset(73)
	scene.sim.max_funds=8
	scene.sim.selected_rewards=["mint","radar","mint"]
	scene.sim.frozen=true
	scene.save_run()
	var expected_draw=scene.sim.draw_offer()
	scene.sim.reset(99)
	scene.load_run()
	check(scene.sim.max_funds==8 and scene.sim.selected_rewards==["mint","radar","mint"] and scene.sim.frozen,"Save restores income base, reward history and freeze")
	check(scene.sim.draw_offer()==expected_draw,"Save restores shop RNG sequence")
	check("2.5" in scene.description("regen",true),"Elite card displays actual cooldown")
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://catalog_economy_test.json")
	DirAccess.remove_absolute("user://catalog_economy_test.cfg")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(failures)
