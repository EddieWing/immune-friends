extends RefCounted
# Rules marked provisional are centralized in data/assumptions.json.
var catalog: Dictionary
var rules: Dictionary
var rng = RandomNumberGenerator.new()
var cells: Array = []
var blood: Array = []
var blood_links: Array = []
var blood_velocity={}
var blood_drag=-1
var blood_target=Vector2.ZERO
var viruses: Array = []
var particles: Array = []
var effects: Array = []
var links: Array = []
var offers: Array = []
var rewards: Array = []
var reward_choices: Array = []
var events: Array = []
var round_losses={"viruses":0,"core":0,"cells":0}
var round_no = 1
var target_rounds = 12
var money = 4
var tier = 1
var xp = 0
var frozen = false
var phase = "shop"
var next_id = 1
var elapsed = 0.0
var spawn_timer = 0.0
var spawn_queue: Array = []
var infection_sources=[]
var source_center=Vector2.ZERO
var wave: Array = []
var last_message = ""
var seed_value = 0

func _init():
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/cells.json").trim_prefix("\ufeff"))
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/assumptions.json").trim_prefix("\ufeff"))

func record(kind: String, detail = {}):
	if kind=="blood_lost":
		detail["hand_neighbors"]=[]
		for link in blood_links:
			var a=blood[link.a]
			var b=blood[link.b]
			if a.id==detail.id and b.alive: detail.hand_neighbors.append(b.id)
			elif b.id==detail.id and a.alive: detail.hand_neighbors.append(a.id)
	var loss_key={"virus_defeated":"viruses","blood_lost":"core","cell_rest":"cells"}.get(kind,"")
	if loss_key!="": round_losses[loss_key]+=1
	events.append({"event":kind, "round":round_no, "time":snappedf(elapsed,0.01), "data":detail})
	if events.size() > 12000:
		events.pop_front()

func reset(seed_number = 42, rounds = 12):
	round_losses={"viruses":0,"core":0,"cells":0}
	rng.seed = seed_number
	seed_value = seed_number
	target_rounds = rounds
	cells.clear()
	blood.clear()
	blood_velocity.clear()
	blood_drag=-1
	viruses.clear()
	particles.clear()
	effects.clear()
	links.clear()
	rewards.clear()
	reward_choices.clear()
	events.clear()
	next_id = 1
	round_no = 1
	tier = 1
	xp = 0
	money = 4
	frozen = false
	phase = "shop"
	var sites=[]
	for q in range(-5,6):
		for r in range(-5,6):
			sites.append(Vector2(26.0*(q+r*0.5),26.0*sqrt(3.0)*r*0.5))
	sites.sort_custom(func(a,b): return a.length_squared()<b.length_squared() if not is_equal_approx(a.length_squared(),b.length_squared()) else a.angle()<b.angle())
	for i in range(int(rules.start_blood)):
		blood.append({"p":sites[i],"alive":true,"id":i})
	rebuild_blood_links()
	roll_shop(false)
	# Reproducible useful first draw; subsequent draws use the provisional pool.
	offers = ["wall","tackle","orbiter"]
	make_wave()
	record("new_run", {"seed":seed_number,"rounds":rounds})

func capacity():
	return 4 + (tier-1)*3

func make_cell(key: String, p: Vector2):
	var d = catalog[key]
	var c = {"id":next_id,"key":key,"p":p,"start":p,"angle":0.0,"start_angle":0.0,
		"hp":float(d.hp),"max_hp":float(d.hp),"rank":1,"alive":true,
		"cool":0.0,"contact":0.0,"flash":0.0,"charge":2 if key=="zapper" else 0,
		"food":0,"sale":1,"orbit":p.angle(),"range_buff":1.0,"speed_buff":1.0}
	next_id += 1
	return c

func compatible(a, b):
	if a.id == b.id or a.rank >= 3 or b.rank >= 3:
		return false
	return a.key == b.key or a.key == "wildcard" or b.key == "wildcard"

func merge(a, b):
	if phase != "shop" or not compatible(a,b) or a.rank+b.rank > 3:
		return false
	if a.key == "wildcard":
		a.key = b.key
	a.max_hp += b.max_hp
	a.hp = a.max_hp
	a.rank += b.rank
	cells.erase(b)
	if a.rank == 3:
		queue_reward()
	rebuild_links()
	record("merge",{"key":a.key,"hp":a.hp,"rank":a.rank})
	effect(a.p,Color("#f6de8d"),"Hug!",48)
	return true

func queue_reward():
	var pool: Array = []
	for key in catalog:
		if int(catalog[key].tier)==0:
			pool.append(key)
	var a = pool[rng.randi_range(0,pool.size()-1)]
	pool.erase(a)
	var b = pool[rng.randi_range(0,pool.size()-1)]
	reward_choices.append([a,b])

func choose_reward(index: int):
	if reward_choices.is_empty() or index < 0 or index > 1:
		return
	rewards.append(reward_choices.pop_front()[index])
	record("reward_chosen")

func purchase(index: int, p: Vector2, reward = false):
	if phase != "shop":
		return false
	var source = rewards if reward else offers
	if index < 0 or index >= source.size():
		return false
	var key = source[index]
	if not reward and money < 2:
		last_message = "You need 2 coins"
		return false
	var item = make_cell(key,p)
	var recipient = {}
	for c in cells:
		if compatible(c,item) and c.rank+item.rank<=3:
			if recipient.is_empty() or c.p.distance_to(p)<recipient.p.distance_to(p):
				recipient=c
	var direct = not recipient.is_empty() and (cells.size()>=capacity() or recipient.p.distance_to(p)<44)
	if cells.size()>=capacity() and not direct:
		last_message = "No room. Merge cells or level up."
		return false
	if not reward:
		money-=2
		if catalog[key].category=="B":
			for c in cells:
				if c.key=="resonant_wall":
					c.max_hp+=1
					c.hp+=1
				if c.key=="resonant_buffer":
					item.max_hp+=1
					item.hp+=1
	source.remove_at(index)
	cells.append(item)
	if direct:
		merge(recipient,item)
	rebuild_links()
	record("purchase",{"key":key,"reward":reward})
	last_message = catalog[key].name + " joined the team"
	return true

func sell(c):
	if phase != "shop" or not cells.has(c):
		return
	money+=int(c.sale)
	record("sell",{"key":c.key,"value":c.sale})
	cells.erase(c)
	rebuild_links()

func roll_shop(pay = true):
	if pay and (money < 1 or phase != "shop"):
		return
	if pay:
		money-=1
	var pool: Array = []
	for key in catalog:
		if int(catalog[key].tier)>0 and int(catalog[key].tier)<=tier:
			pool.append(key)
	offers.clear()
	for i in range(tier+2):
		offers.append(pool[rng.randi_range(0,pool.size()-1)])
	record("shop_roll")

func buy_xp():
	if phase!="shop" or money<3 or tier>=4:
		return false
	money-=3
	xp+=1
	if xp>=int(rules.xp_thresholds[tier-1]):
		tier+=1
	record("xp",{"tier":tier,"xp":xp})
	return true

func cell_by_id(id):
	for c in cells:
		if c.id==id:
			return c
	return {}

func rebuild_links():
	links.clear()
	for c in cells:
		if catalog[c.key].behavior!="bond":
			continue
		var near = cells.duplicate()
		near.erase(c)
		near.sort_custom(func(a,b): return a.p.distance_squared_to(c.p)<b.p.distance_squared_to(c.p))
		var count = 1 if c.key=="swapper" else 2
		for other in near:
			if count<=0:
				break
			if c.p.distance_to(other.p)>float(rules.bond_distance):
				continue
			var exists=false
			for link in links:
				if (link.a==c.id and link.b==other.id) or (link.b==c.id and link.a==other.id):
					exists=true
			if not exists:
				links.append({"a":c.id,"b":other.id,"rest":maxf(42,c.p.distance_to(other.p)),"owner":c.id})
			count-=1

func network(id):
	var found=[id]
	var cursor=0
	while cursor<found.size():
		var here=found[cursor]
		cursor+=1
		for l in links:
			var other=l.b if l.a==here else (l.a if l.b==here else -1)
			if other==-1 or found.has(other):
				continue
			var c=cell_by_id(other)
			if not c.is_empty() and c.alive:
				found.append(other)
	return found

func range_of(c):
	var r=float(catalog[c.key].range)*float(rules.scale)
	if c.rank==3:
		if c.key=="seeker": r=40*float(rules.scale)
		if c.key=="bomb": r=20*float(rules.scale)
	return r*float(c.range_buff)

func interval_of(c):
	if c.key=="tag_dropper" and c.rank==3:
		return 0.25
	return float(catalog[c.key].interval)

func make_wave():
	make_infection_sources()
	var basic=2 if round_no==1 else 4
	wave=[{"type":"basic","count":basic,"lane":0}]
	if round_no>=3:
		wave.append({"type":"wave" if seed_value%2==0 else "jumper","count":3 if round_no==3 else 6,"lane":0})
	if round_no>=5:
		wave.append({"type":"wave" if seed_value%2==0 else "hungry","count":5 if round_no==5 else 11,"lane":1})
	if round_no>=7:
		wave.append({"type":"seeker" if seed_value%2==0 else "swarmer","count":8 if round_no==7 else 17,"lane":2})
	if round_no>=9:
		wave.append({"type":"swarmer","count":12+(round_no-9)*14,"lane":1})
	if round_no>=11:
		wave.append({"type":"avoider","count":12+(round_no-11)*8,"lane":0})

func begin_battle():
	if phase!="shop" or not reward_choices.is_empty():
		return
	round_losses={"viruses":0,"core":0,"cells":0}
	phase="battle"
	elapsed=0
	spawn_timer=0
	viruses.clear()
	particles.clear()
	spawn_queue.clear()
	rebuild_links()
	for c in cells:
		c.start=c.p
		c.start_angle=c.angle
		c.cool=0.1
		c.contact=0
		c.range_buff=1.0
		c.speed_buff=1.0
		c.orbit=c.p.angle()
		c.alive=true
		c.hp=c.max_hp
		c.charge=2 if c.key=="zapper" else 0
	for c in cells:
		for id in network(c.id):
			var n=cell_by_id(id)
			if n.key=="radar": c.range_buff=float(rules.radar_multiplier)
			if n.key=="accelerator": c.speed_buff=float(rules.accelerator_multiplier)
	for entry in wave:
		for i in range(entry.count):
			spawn_queue.append({"type":entry.type,"lane":entry.lane})
	# Interleave lanes, preserving deterministic timing for a given seed.
	for i in range(spawn_queue.size()-1,0,-1):
		var j=rng.randi_range(0,i)
		var temp=spawn_queue[i]
		spawn_queue[i]=spawn_queue[j]
		spawn_queue[j]=temp
	record("battle_start")

func make_infection_sources():
	var config=rules.infection_sources
	var source_rng=RandomNumberGenerator.new()
	source_rng.seed=seed_value+round_no*104729
	source_center=Vector2.ZERO
	var alive=blood.filter(func(b): return b.alive)
	for b in alive: source_center+=b.p
	if not alive.is_empty(): source_center/=alive.size()
	infection_sources.clear()
	var minimum=maxf(1,config.distance_min)
	var maximum=maxf(minimum,config.distance_max)
	for angle in [0.0,PI,-PI/2]:
		var jitter=deg_to_rad(clampf(config.angle_jitter_degrees,0,45))
		var direction=Vector2.from_angle(angle+source_rng.randf_range(-jitter,jitter))
		infection_sources.append(source_center+direction*source_rng.randf_range(minimum,maximum))

func spawn_virus(entry):
	var config=rules.infection_sources
	var p=infection_sources[entry.lane]
	var inward=p.direction_to(source_center)
	var exit=p+inward*maxf(1,config.exit_distance)+inward.orthogonal()*rng.randf_range(-config.exit_spread,config.exit_spread)
	var hp=2.0 if entry.type=="seeker" else 1.0
	viruses.append({"id":next_id,"type":entry.type,"p":p,"hp":hp,"alive":true,
		"cool":0.0,"tag":0.0,"freeze":0.0,"age":0.0,"jump":false,"phase":rng.randf()*TAU,
		"emerging":true,"exit":exit})
	next_id+=1

func nearest_virus(p, reach=10000.0):
	var best={}
	var dist=reach
	for v in viruses:
		if not v.alive: continue
		var d=p.distance_to(v.p)
		if d<dist:
			dist=d
			best=v
	return best

func nearest_blood(p):
	var best={}
	var dist=INF
	for b in blood:
		if b.alive and p.distance_squared_to(b.p)<dist:
			dist=p.distance_squared_to(b.p)
			best=b
	return best

func effect(p, color, label="", radius=30.0):
	effects.append({"p":p,"color":color,"text":label,"r":radius,"life":0.8,"max":0.8})

func shoot(c, direction, origin=Vector2.INF, split=false):
	var p=c.p if origin==Vector2.INF else origin
	var radius=5.0
	if c.key=="cannon":
		var count=0
		for n in cells:
			if catalog[n.key].category=="B": count+=1
		radius+=count*0.65
	particles.append({"kind":"bullet","p":p,"v":direction.normalized()*float(rules.bullet_speed),
		"life":4.0,"r":radius,"owner":c.id,"split":split})
	effect(p,Color(catalog[c.key].color),"",10)

func heal(c, amount):
	if not c.alive: return
	c.hp+=amount
	c.flash=0.3
	effect(c.p,Color("#a3e4b6"),"+1",24)
	record("heal",{"id":c.id,"hp":c.hp})

func damage_cell(c, amount, redirected=false):
	if not c.alive: return
	if not redirected:
		for id in network(c.id):
			var guard=cell_by_id(id)
			if guard.id!=c.id and guard.key=="bodyguard" and guard.alive:
				damage_cell(guard,amount,true)
				return
	c.hp-=amount
	c.flash=0.25
	record("damage",{"id":c.id,"hp":c.hp})
	if c.key=="impact_wall":
		var dir=Vector2.RIGHT.rotated(c.angle)
		shoot(c,dir,c.p+dir*42)
		shoot(c,-dir,c.p-dir*42)
	if c.hp>0: return
	c.alive=false
	effect(c.p,Color(catalog[c.key].color),"",40)
	if c.key=="bomb":
		var reach=range_of(c)
		effect(c.p,Color("#f9b8d1"),"Pop!",reach)
		for v in viruses:
			if v.alive and c.p.distance_to(v.p)<reach:
				v.p+=(v.p-c.p).normalized()*40
				damage_virus(v,float(rules.bomb_damage))
		for other in cells:
			if other.alive and c.p.distance_to(other.p)<reach:
				other.p+=(other.p-c.p).normalized()*28
				damage_cell(other,float(rules.bomb_damage))
	if c.key=="bandage":
		for other in cells:
			if other.alive and c.p.distance_to(other.p)<range_of(c):
				heal(other,1)
	record("cell_rest",{"id":c.id,"p":c.p})

func damage_virus(v, amount):
	if not v.alive or v.jump: return
	v.hp-=amount
	if v.hp>0: return
	v.alive=false
	particles.append({"kind":"food","p":v.p,"v":Vector2.ZERO,"life":float(rules.protein_lifetime),"r":4.0,"owner":-1})
	effect(v.p,Color("#d4b8e7"),"",20)
	record("virus_defeated",{"type":v.type,"id":v.id,"p":v.p})

func contains_cell(c, p, extra=0.0):
	var local=(p-c.p).rotated(-c.angle)
	if catalog[c.key].behavior=="wall":
		return absf(local.x)<43+extra and absf(local.y)<13+extra
	return local.length()<18+extra

func update(delta):
	var movement_delta=delta*float(rules.get("movement_multiplier",1.0))
	for e in effects: e.life-=delta
	effects=effects.filter(func(e): return e.life>0)
	for c in cells: c.flash=maxf(0,c.flash-delta)
	if phase in ["shop","battle"]: step_blood(delta)
	if phase!="battle": return
	elapsed+=delta
	spawn_timer-=delta
	if spawn_timer<=0 and not spawn_queue.is_empty():
		spawn_virus(spawn_queue.pop_front())
		spawn_timer=0.38
	for c in cells:
		if not c.alive: continue
		c.range_buff=1.0
		c.speed_buff=1.0
		for id in network(c.id):
			var provider=cell_by_id(id)
			if provider.key=="radar": c.range_buff=float(rules.radar_multiplier)
			if provider.key=="accelerator": c.speed_buff=float(rules.accelerator_multiplier)
		c.cool-=delta
		c.contact=maxf(0,c.contact-delta)
		var d=catalog[c.key]
		var velocity=Vector2.ZERO
		var reach=range_of(c)
		var target=nearest_virus(c.p,reach)
		if target.is_empty() and d.category=="T" and reach>0:
			for candidate in viruses:
				if candidate.alive and candidate.tag>0 and c.p.distance_to(candidate.p)<reach*2:
					target=candidate
					break
		if d.behavior=="forward" or d.behavior=="drop":
			velocity=Vector2.RIGHT.rotated(c.angle)*float(d.speed)*3
		elif d.behavior=="seek":
			# Tagged targets can be detected at twice the normal distance.
			if target.is_empty():
				for v in viruses:
					if v.alive and v.tag>0 and c.p.distance_to(v.p)<reach*2:
						target=v
						break
			if not target.is_empty(): velocity=c.p.direction_to(target.p)*float(d.speed)*3
		elif d.behavior=="orbit":
			var radius=maxf(100,c.start.length())
			c.orbit-=float(d.speed)*3/radius*movement_delta
			var desired=Vector2.from_angle(c.orbit)*radius
			velocity=(desired-c.p).limit_length(float(d.speed)*3)
		c.p+=velocity*movement_delta*float(c.speed_buff)
		c.p=c.p.clamp(Vector2(-620,-365),Vector2(620,350))
		if c.cool<=0:
			c.cool=maxf(0.05,interval_of(c))
			match d.behavior:
				"shoot":
					if not target.is_empty(): shoot(c,target.p-c.p)
				"sniper":
					var dir=Vector2.RIGHT.rotated(c.angle)
					for candidate in viruses:
						if candidate.alive and c.p.distance_to(candidate.p)<reach and absf(dir.angle_to(candidate.p-c.p))<0.20:
							shoot(c,dir)
							break
				"heal":
					for other in cells:
						if other.alive and other.p.distance_to(c.p)<reach: heal(other,1)
				"push":
					effect(c.p,Color("#f7dec3"),"",reach)
					for v in viruses:
						if v.alive and v.p.distance_to(c.p)<reach: v.p+=(v.p-c.p).normalized()*30
					for other in cells:
						if other.id!=c.id and other.alive and other.p.distance_to(c.p)<reach: other.p+=(other.p-c.p).normalized()*20
				"drop":
					particles.append({"kind":"tag","p":c.p,"v":Vector2.ZERO,"life":8.0,"r":5.0,"owner":c.id})
				"spray":
					var angle=c.angle+rng.randf_range(-PI/2,PI/2)
					particles.append({"kind":"tag","p":c.p,"v":Vector2.from_angle(angle)*95,"life":reach/95,"r":5.0,"owner":c.id})
		if c.key=="magnet":
			for v in viruses:
				if v.alive and v.p.distance_to(c.p)<reach: v.p+=v.p.direction_to(c.p)*60*movement_delta
		if c.key=="generator":
			for p in particles:
				if p.kind=="food" and p.life>0 and p.p.distance_to(c.p)<45:
					p.life=0
					c.food+=1
			if c.food>=8:
				c.food-=8
				c.charge+=8
		if c.charge>0:
			conduct(c)
	# Spring-like position constraints allow entire connected components to move.
	for pass_no in range(3):
		for l in links:
			var a=cell_by_id(l.a)
			var b=cell_by_id(l.b)
			if not a.alive or not b.alive: continue
			var offset=b.p-a.p
			var length=offset.length()
			if length>1:
				var correction=offset/length*(length-l.rest)*float(rules.bond_stiffness)*0.5
				a.p+=correction
				b.p-=correction
	# Soft body separation; walls use their oriented rectangle, not a circular hitbox.
	for i in range(cells.size()):
		var a=cells[i]
		if not a.alive: continue
		for j in range(i+1,cells.size()):
			var b=cells[j]
			if not b.alive: continue
			var offset=b.p-a.p
			var length=offset.length()
			var direction=offset.normalized() if length>0.01 else Vector2.RIGHT
			var radius_a=body_radius(a,direction)
			var radius_b=body_radius(b,-direction)
			if length<radius_a+radius_b:
				var correction=direction*(radius_a+radius_b-length)*0.3
				a.p-=correction
				b.p+=correction
	for c in cells:
		c.p=c.p.clamp(Vector2(-620,-365),Vector2(620,350))
	for v in viruses:
		if not v.alive: continue
		v.age+=delta
		v.cool=maxf(0,v.cool-delta)
		v.tag=maxf(0,v.tag-delta)
		v.freeze=maxf(0,v.freeze-delta)
		if v.get("emerging",false):
			v.jump=false
			if v.freeze<=0:
				v.p=v.p.move_toward(v.exit,maxf(1,rules.infection_sources.emerge_speed)*movement_delta)
			if v.p.is_equal_approx(v.exit):
				v.emerging=false
				v.age=0.0
			continue
		v.jump=v.type=="jumper" and fmod(v.age+v.phase,3.5)>2.8
		var destination=nearest_blood(v.p)
		if destination.is_empty():
			finish(false)
			return
		var target_pos=destination.p
		if v.type=="seeker":
			var nearest=125.0
			for c in cells:
				if c.alive and c.p.distance_to(v.p)<nearest:
					target_pos=c.p
					nearest=c.p.distance_to(v.p)
		var dir=v.p.direction_to(target_pos)
		var speed=float(rules.virus_speed)
		if v.type=="wave": dir=dir.rotated(sin(v.age*3+v.phase)*0.8)
		if v.type=="jumper": speed=130 if v.jump else 20
		if v.type=="avoider":
			for c in cells:
				if c.alive and c.p.distance_to(v.p)<80:
					dir=(dir+(v.p-c.p).normalized()*1.8).normalized()
		if v.type=="swarmer":
			var host={}
			for other in viruses:
				if other.id==v.get("host",-1) and other.alive: host=other
			if not host.is_empty():
				v.p=host.p+Vector2.from_angle(v.phase)*17
				speed=0
			else:
				v.host=-1
				for other in viruses:
					if other.id!=v.id and other.alive and other.type!="swarmer" and other.p.distance_to(v.p)<100:
						dir=v.p.direction_to(other.p)
						if other.p.distance_to(v.p)<22: v.host=other.id
						break
		if v.freeze<=0: v.p+=dir*speed*movement_delta
		if v.type=="hungry":
			for p in particles:
				if p.kind=="food" and p.life>0 and p.p.distance_to(v.p)<20:
					p.life=0
					v.hp+=1
		for c in cells:
			if not c.alive or v.jump: continue
			if contains_cell(c,v.p,10):
				var away=(v.p-c.p).normalized()
				if away==Vector2.ZERO: away=Vector2.RIGHT
				v.p+=away*speed*movement_delta
				if v.cool<=0:
					v.cool=float(rules.contact_interval)
					damage_cell(c,float(rules.contact_damage))
					damage_virus(v,float(rules.contact_damage))
		if v.alive and v.p.distance_to(destination.p)<19:
			destination.alive=false
			v.alive=false
			record("virus_defeated",{"type":v.type,"id":v.id,"p":v.p})
			effect(destination.p,Color("#eb8f9d"),"",35)
			record("blood_lost",{"id":destination.id,"p":destination.p})
	for p in particles:
		if p.life<=0: continue
		p.life-=delta
		p.p+=p.v*movement_delta
		if p.kind=="bullet":
			for c in cells:
				if c.alive and c.key=="bullet_wall" and c.id!=p.owner and not p.get("split",false) and contains_cell(c,p.p,5):
					p.life=0
					var dir=p.v.normalized()
					shoot(c,dir.rotated(-0.18),c.p+dir*48,true)
					shoot(c,dir.rotated(0.18),c.p+dir*48,true)
					break
			if p.life<=0: continue
			for v in viruses:
				if v.alive and not v.jump and v.p.distance_to(p.p)<12+p.r:
					damage_virus(v,float(rules.bullet_damage))
					p.life=0
					break
		elif p.kind=="tag":
			for v in viruses:
				if v.alive and v.p.distance_to(p.p)<17:
					v.tag=4
					v.freeze=1
					p.life=0
					break
	particles=particles.filter(func(p): return p.life>0)
	viruses=viruses.filter(func(v): return v.alive)
	if elapsed>=float(rules.max_battle_seconds) and not viruses.is_empty():
		# Explicit provisional resolution for an otherwise infinite freeze/stall.
		for v in viruses:
			var b=nearest_blood(v.p)
			if not b.is_empty():
				b.alive=false
				record("blood_lost",{"id":b.id,"p":b.p})
		viruses.clear()
		spawn_queue.clear()
		record("provisional_stalemate_resolution")
	if blood.filter(func(b): return b.alive).is_empty():
		finish(false)
	elif spawn_queue.is_empty() and viruses.is_empty():
		if round_no>=target_rounds: finish(true)
		else: phase="recap"

func conduct(c):
	# Provisional graph: objects within charge_range conduct one charge per victim.
	var points=[c.p]
	var seen={}
	var cursor=0
	while cursor<points.size() and cursor<200:
		var p=points[cursor]
		cursor+=1
		for v in viruses:
			if v.alive and not v.jump and p.distance_to(v.p)<float(rules.charge_range):
				c.charge-=1
				effects.append({"p":p,"end":v.p,"color":Color("#fff3a9"),"text":"","r":0,"life":0.35,"max":0.35})
				damage_virus(v,999)
				record("charge_kill",{"source":c.id})
				return
		for other in cells:
			if other.alive and not seen.has(other.id) and p.distance_to(other.p)<float(rules.charge_range):
				seen[other.id]=true
				points.append(other.p)
		for i in range(particles.size()):
			var particle=particles[i]
			if particle.life>0 and not seen.has(-i-1) and p.distance_to(particle.p)<float(rules.charge_range):
				seen[-i-1]=true
				points.append(particle.p)

func next_round():
	if phase!="recap": return
	for c in cells:
		if c.key=="bank" and c.alive: c.sale+=1
		c.p=c.start
		c.angle=c.start_angle
		c.hp=c.max_hp
		c.alive=true
		c.charge=2 if c.key=="zapper" else 0
	# Capture all exchanges before modifying persistent health.
	var exchanges=[]
	for c in cells:
		if c.key!="swapper": continue
		for l in links:
			if l.owner==c.id:
				var other=cell_by_id(l.b)
				exchanges.append([c,other,c.max_hp,other.max_hp])
				break
	for swap in exchanges:
		swap[0].max_hp=swap[3]
		swap[0].hp=swap[3]
		swap[1].max_hp=swap[2]
		swap[1].hp=swap[2]
		record("swap",{"a":swap[0].id,"b":swap[1].id})
	round_no+=1
	money=mini(round_no+3,10)
	phase="shop"
	particles.clear()
	effects.clear()
	if not frozen: roll_shop(false)
	make_wave()
	rebuild_links()
	record("shop_start",{"money":money})

func finish(won):
	phase="win" if won else "lose"
	record("result",{"won":won,"round":round_no})

func body_radius(c, direction):
	if catalog[c.key].behavior!="wall": return 18.0
	var local=direction.rotated(-c.angle).abs()
	return minf(43.0/maxf(0.001,local.x),13.0/maxf(0.001,local.y))

# Provisional soft-body constraints: touching membranes, fixed neighbour links.
func rebuild_blood_links():
	blood_links.clear()
	var connected=[]
	for i in range(blood.size()):
		if blood[i].alive: connected.append(i); break
	while not connected.is_empty():
		var closest=INF
		var pair=[]
		for a in connected:
			for b in range(blood.size()):
				if b in connected or not blood[b].alive: continue
				var distance=blood[a].p.distance_to(blood[b].p)
				if distance<closest: closest=distance; pair=[a,b]
		if pair.is_empty(): break
		blood_links.append({"a":pair[0],"b":pair[1],"rest":26.0})
		connected.append(pair[1])
	for a in range(blood.size()):
		for b in range(a+1,blood.size()):
			if blood[a].alive and blood[b].alive and blood[a].p.distance_to(blood[b].p)<28:
				if not blood_links.any(func(l): return (l.a==a and l.b==b) or (l.a==b and l.b==a)):
					blood_links.append({"a":a,"b":b,"rest":26.0})
	solve_blood()

func solve_blood():
	for iteration in range(24):
		var adjusted=false
		for link in blood_links:
			var a=blood[link.a]
			var b=blood[link.b]
			if not a.alive or not b.alive: continue
			var offset=b.p-a.p
			var distance=offset.length()
			if distance>26.05:
				adjusted=true
				var correction=offset/distance*(distance-26.0)*0.35
				a.p+=correction
				b.p-=correction
		for i in range(blood.size()):
			var a=blood[i]
			if not a.alive: continue
			for j in range(i+1,blood.size()):
				var b=blood[j]
				if not b.alive: continue
				var offset=b.p-a.p
				var distance=offset.length()
				if distance<25.999:
					adjusted=true
					var direction=offset/distance if distance>0.0001 else Vector2.RIGHT.rotated(i*2.4)
					var correction=direction*(26.0-distance)*0.5
					a.p-=correction
					b.p+=correction
		if not adjusted: break

func move_blood(index,target):
	if index<0 or index>=blood.size() or not blood[index].alive: return
	blood_drag=index
	blood_target=target.clamp(Vector2(-550,-300),Vector2(550,280))

func release_blood():
	blood_drag=-1

func step_blood(delta):
	var count=maxi(1,int(ceil(minf(delta,0.1)*120)))
	var dt=minf(delta,0.1)/count
	var config=rules.blood_elasticity
	for step in range(count):
		# Translate the living cluster uniformly: centering must not compress its springs.
		if blood_drag<0:
			var center=Vector2.ZERO
			var living=0
			for b in blood:
				if b.alive: center+=b.p; living+=1
			if living>0:
				center/=living
				var drift=rules.blood_drift
				var rate=float(drift.speed)/maxf(1,float(drift.slow_radius))
				var offset=center*(exp(-rate*dt)-1.0)
				for b in blood:
					if b.alive: b.p+=offset
		var forces={}
		for i in range(blood.size()): forces[i]=Vector2.ZERO
		for link in blood_links:
			var a=blood[link.a]
			var b=blood[link.b]
			if not a.alive or not b.alive: continue
			var offset=b.p-a.p
			var distance=offset.length()
			if distance<0.001: continue
			var force=offset/distance*(distance-26.0)*float(config.stiffness)
			forces[int(link.a)]+=force
			forces[int(link.b)]-=force
		for i in range(blood.size()):
			if not blood[i].alive: continue
			var velocity=blood_velocity.get(i,Vector2.ZERO)
			velocity=(velocity+forces[i]*dt)*exp(-float(config.damping)*dt)
			velocity=velocity.limit_length(650)
			if i==blood_drag:
				var next=blood[i].p.move_toward(blood_target,650*dt)
				velocity=(next-blood[i].p)/maxf(dt,0.00001)
			blood[i].p=(blood[i].p+velocity*dt).clamp(Vector2(-550,-300),Vector2(550,280))
			blood_velocity[i]=velocity
		for iteration in range(8):
			for i in range(blood.size()):
				if not blood[i].alive: continue
				for j in range(i+1,blood.size()):
					if not blood[j].alive: continue
					var offset=blood[j].p-blood[i].p
					var distance=offset.length()
					if distance>=26: continue
					var normal=offset/distance if distance>0.001 else Vector2.RIGHT.rotated(i*2.4)
					var wa=0.0 if i==blood_drag else 1.0
					var wb=0.0 if j==blood_drag else 1.0
					var correction=normal*(26-distance)/(wa+wb)
					blood[i].p-=correction*wa
					blood[j].p+=correction*wb


