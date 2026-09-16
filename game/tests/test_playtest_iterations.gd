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
func _initialize():
	var s=Sim.new()
	s.reset()
	s.blood=[{"id":1,"p":Vector2(0,0),"alive":true},{"id":2,"p":Vector2(0,50),"alive":true}]
	s.blood_links=[]
	var guard=add(s,"bodyguard",Vector2(40,25))
	s.rebuild_links()
	check(s.links.size()==2 and s.links.all(func(l):return l.b< -1),"Bodyguard links two Core with separate IDs")
	var regen=add(s,"regen",Vector2(45,25))
	s.rebuild_links()
	check(s.links.any(func(l):return l.b==regen.id),"Nearby support replaces one Core partner")
	regen.p=Vector2(500,0)
	s.rebuild_links()
	var v={"id":999,"p":Vector2.ZERO,"alive":true}
	s.hit_core(s.blood[0],v)
	check(s.blood[0].alive and guard.hp==6 and not v.alive,"Core intercept consumes contact and damages guard")
	s.damage_cell(guard,100,true)
	v.alive=true
	s.hit_core(s.blood[0],v)
	check(not s.blood[0].alive,"Dead Bodyguard cannot protect Core")
	s.reset()
	s.gym_mode=true
	s.blood=[]
	s.blood_links=[]
	var seeker=add(s,"seeker",Vector2(-100,0))
	var bond=add(s,"bond",Vector2(-160,30))
	var wall=add(s,"wall",Vector2(-220,50))
	s.begin_battle()
	s.spawn_queue.clear()
	s.viruses=[{"id":900,"type":"basic","p":Vector2(-30,0),"hp":1000,"alive":true,"cool":100.0,"tag":0.0,"freeze":100.0,"age":0.0,"jump":false,"phase":0.0}]
	for i in range(30): s.update(0.016)
	check(wall.p.distance_to(wall.start)>1 and bond.p.distance_to(bond.start)>1,"Seeker tows two passive bodies")
	s.push_object(wall,Vector2(0,20),"cell",wall.p+Vector2(30,0))
	check(absf(wall.angle)>0.001,"Off-centre wall force produces rotation")
	s.phase="recap"
	s.next_round()
	check(wall.p==wall.start and wall.angle==wall.start_angle,"Next shop restores position and rotation")
	s.reset()
	s.gym_mode=true
	var pusher=add(s,"pusher",Vector2(300,0))
	wall=add(s,"wall",Vector2(320,20))
	s.begin_battle()
	s.spawn_queue.clear()
	s.update(0.11)
	check(s.events.any(func(e):return e.event=="pushed" and e.data.id==wall.id),"Pusher acts on own wall without enemies")
	s.reset()
	s.gym_mode=true
	var mortar=add(s,"mortar",Vector2(300,0))
	var mint=add(s,"mint",Vector2(-300,0))
	var splitter=add(s,"tag_splitter",Vector2(0,200))
	var dropper=add(s,"tag_drag",Vector2(-200,-200))
	s.proteins.drag(s,dropper,Vector2(-110,-200))
	check(dropper.tags==13 and s.particles.size()==2,"Tag drag spends stock by travelled distance")
	s.begin_battle()
	s.spawn_queue.clear()
	check(s.particles.size()==2,"Preparation tags enter battle")
	for c in [mortar,mint,splitter]:
		var kind="bullet" if c==mortar else ("food" if c==mint else "tag")
		var count=4 if c==mortar else (1 if c==mint else 3)
		for i in range(count): s.particles.append({"kind":kind,"p":c.p,"v":Vector2.ZERO,"life":10.0,"r":5.0,"owner":-1})
	s.update(0.016)
	check(s.cells.any(func(c):return c.key=="bomb" and c.get("temporary",false)),"Mortar consumes bullets and creates Bomb")
	check(s.cells.filter(func(c):return c.key=="tag_splitter").size()==2,"Three tags produce a second Splitter")
	check(s.battle_income==1,"Mint earns tracked battle income")
	s.phase="recap"
	s.next_round()
	check(s.money==6 and s.battle_income==0,"Mint adds income without carrying unused starting money")
	check(s.cells.size()==4,"Produced copies do not pollute next shop roster")
	s.proteins.pickup(s,dropper)
	check(dropper.tags==15,"Next-round pickup replenishes Tag stock")
	s.reset()
	s.gym_mode=true
	var greed=add(s,"greed_wall",Vector2(300,0))
	var survivor=add(s,"survivor_bomb",Vector2(-300,0))
	s.money=5
	s.begin_battle()
	check(greed.hp==12 and greed.max_hp==2,"Greed applies temporary unspent-money bonus")
	s.phase="recap"
	s.next_round()
	check(greed.hp==2 and survivor.radius_growth==8,"Shop resets Greed and retains survival growth")
	s.begin_battle()
	s.phase="recap"
	s.next_round()
	check(s.range_of(survivor)==28*s.rules.scale,"Survivor radius grows 12 to 28 after two rounds")
	s.reset()
	check(s.cells.is_empty() and s.money==4 and s.tier==1,"New run resets progression")
	s.money=100
	for i in range(10): s.buy_xp()
	check(s.tier==5 and s.capacity()==16 and not s.buy_xp(),"Tier 5 reaches 16 slots and is capped")
	s.reset()
	s.gym_mode=true
	var radar=add(s,"radar",Vector2(300,0))
	var sniper=add(s,"sniper",Vector2(360,0))
	var orbiter=add(s,"orbiter",Vector2(-300,0))
	orbiter.rank=3
	s.begin_battle()
	check(s.range_of(sniper)==100*s.rules.scale,"Radar adds 20 to Sniper instead of multiplying by 1.5")
	check(s.speed_of(orbiter)==25,"Elite Orbiter has observed speed 25")
	quit(failures)
