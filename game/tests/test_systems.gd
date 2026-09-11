extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=0
var checks=0
func check(ok, message):
	checks+=1
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func add(s,key,p):
	var c=s.make_cell(key,p)
	s.cells.append(c)
	return c
func _initialize():
	call_deferred("run")
func run():
	var s=Sim.new()
	s.reset(42,12)
	var wall=add(s,"wall",Vector2.ZERO)
	var bridge=add(s,"bond",Vector2(70,0))
	var guard=add(s,"bodyguard",Vector2(140,0))
	s.rebuild_links()
	s.damage_cell(wall,2)
	check(wall.hp==3 and guard.hp==5,"bodyguard protects beyond direct neighbour")
	s.damage_cell(guard,99,true)
	s.damage_cell(wall,1)
	check(wall.hp==2,"dead guard stops redirecting")
	s.reset()
	var radar=add(s,"radar",Vector2.ZERO)
	var turret=add(s,"turret",Vector2(70,0))
	s.begin_battle()
	s.update(0.01)
	check(turret.range_buff==1.5,"radar network active")
	s.damage_cell(radar,100,true)
	s.update(0.01)
	check(turret.range_buff==1.0,"radar effect removed on death")
	s.reset()
	var zapper=add(s,"zapper",Vector2(220,0))
	s.begin_battle()
	s.spawn_queue.clear()
	s.viruses.clear()
	s.spawn_virus({"type":"basic","lane":0})
	s.viruses[0].p=Vector2(250,0)
	s.update(0.01)
	check(zapper.charge==1 and s.viruses.is_empty(),"electric charge consumes charge and kills")
	s.reset()
	var generator=add(s,"generator",Vector2(200,0))
	s.begin_battle()
	for i in range(8):
		s.particles.append({"kind":"food","p":Vector2(200,0),"v":Vector2.ZERO,"life":10.0,"r":4.0,"owner":-1})
	s.update(0.01)
	check(generator.charge==8 and generator.food==0,"generator converts eight proteins")
	s.reset()
	var bw=add(s,"bullet_wall",Vector2(200,0))
	var gun=add(s,"turret",Vector2(100,0))
	s.begin_battle()
	s.particles.clear()
	s.shoot(gun,Vector2.RIGHT,Vector2(165,0))
	s.update(0.02)
	check(s.particles.filter(func(p):return p.kind=="bullet").size()==2,"bullet wall consumes one and creates two")
	s.reset()
	add(s,"tag_dropper",Vector2(-500,0))
	s.begin_battle()
	s.spawn_queue.clear()
	s.viruses.clear()
	s.spawn_virus({"type":"basic","lane":0})
	s.viruses[0].p=Vector2(300,0)
	s.particles.append({"kind":"tag","p":Vector2(300,0),"v":Vector2.ZERO,"life":3.0,"r":4.0,"owner":-1})
	s.update(0.01)
	check(s.viruses[0].freeze==1.0 and s.viruses[0].tag==4.0,"tag freezes and marks")
	# Complete multi-round sessions driven only by legal shop purchases.
	for seed_no in [42,43,100]:
		s.reset(seed_no,12)
		var rounds_seen=0
		while s.phase not in ["win","lose"] and rounds_seen<12:
			rounds_seen+=1
			if s.round_no==2 or (s.round_no>=4 and s.tier<4 and s.money>=6):
				s.buy_xp()
			var attempts=0
			while s.money>=2 and attempts<12:
				attempts+=1
				var choice=-1
				for i in range(s.offers.size()):
					var key=s.offers[i]
					if key in ["wall","seeker","turret","tackle","orbiter","bomb","resonant_wall","bodyguard"]:
						choice=i
						break
				if choice<0:
					s.roll_shop()
					continue
				var p=Vector2(110+(s.cells.size()%3)*50,-65+(s.cells.size()%4)*42)
				if not s.purchase(choice,p):
					break
				while not s.reward_choices.is_empty(): s.choose_reward(0)
				if not s.rewards.is_empty(): s.purchase(0,p+Vector2(-100,0),true)
			s.begin_battle()
			for step in range(60*185):
				s.update(1.0/60.0)
				if s.phase!="battle": break
			if s.phase=="recap": s.next_round()
			elif s.phase=="battle": break
		check(s.phase in ["win","lose"],"complete legal run seed "+str(seed_no)+" → "+s.phase+" R"+str(s.round_no))
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
