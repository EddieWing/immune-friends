extends RefCounted
# Rules marked provisional are centralized in data/assumptions.json.
var shop_rules: Dictionary
var selected_rewards: Array = []
var max_funds = 3
var bonds=preload("res://scripts/bond_system.gd").new()
var physics=preload("res://scripts/body_physics.gd").new()
var tuning={}
var experimental=false
var experiments=preload("res://scripts/experimental_system.gd").new()
var virus_motion=preload("res://scripts/virus_motion.gd").new()
var proteins=preload("res://scripts/protein_system.gd").new()
var pending_cells=[]
var battle_income=0
var catalog: Dictionary
var base_catalog: Dictionary
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
var blasts: Array = []
var links: Array = []
var offers: Array = []
var rewards: Array = []
var reward_choices: Array = []
var events: Array = []
var event_sequence=0
var presentation_revision=0
var round_losses={"viruses":0,"core":0,"cells":0}
var round_no = 1
var target_rounds = 12
var money = 4
var tier = 1
var xp = 0
var frozen = false
var phase = "shop"
var gym_mode=false
var next_id = 1
var elapsed = 0.0
const SPAWN_INTERVAL = 1.5 # Fallback for manually inserted debug/Gym entries.
var source_emitters: Array = []
var infection_plan=preload("res://scripts/infection_plan.gd").new()
var spawn_timer = 0.0
var spawn_queue: Array = []
var infection_sources=[]
var source_center=Vector2.ZERO
var wave: Array = []
var last_message = ""
var seed_value = 0

func _init():
	shop_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/shop_rules.json"))
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/cells.json").trim_prefix("\ufeff"))
	base_catalog=catalog.duplicate(true)
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/assumptions.json").trim_prefix("\ufeff"))

func apply_tuning(key, values):
	if key=="__core":
		for path in values:
			var parts=path.split("/")
			if parts.size()==2 and parts[0] in ["blood_drift","blood_elasticity","blood_faces"] and rules[parts[0]].has(parts[1]): rules[parts[0]][parts[1]]=values[path]
	elif key.begins_with("virus:"):
		var kind=key.trim_prefix("virus:")
		var previous=tuning.get(key,{}).get("hp",2.0 if kind=="seeker" else 1.0)
		for virus in viruses:
			if virus.alive and virus.type==kind:
				virus.hp=maxf(0.1,virus.hp+float(values.get("hp",previous))-previous)
				virus.peak_hp=maxf(virus.hp,virus.get("peak_hp",virus.hp))
	elif catalog.has(key):
		var previous=float(catalog[key].hp)
		for field in ["hp","range","speed","interval"]:
			if values.has(field): catalog[key][field]=values[field]
		for cell in cells+pending_cells:
			if cell.alive and cell.key==key:
				var change=(float(catalog[key].hp)-previous)*cell.rank
				cell.max_hp=maxf(1,cell.max_hp+change)
				cell.hp=maxf(0.1,cell.hp+change)
	tuning[key]=values.duplicate(true)

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
	event_sequence+=1
	events.append({"seq":event_sequence,"event":kind, "round":round_no, "time":snappedf(elapsed,0.01), "data":detail})
	if events.size() > 12000:
		events.pop_front()

func events_since(sequence):
	if events.is_empty(): return []
	var first=int(events[0].get("seq",1))
	return events.slice(clampi(sequence-first+1,0,events.size()))

func reset(seed_number = 42, rounds = 12):
	physics.clear()
	blasts.clear()
	presentation_revision+=1
	elapsed=0.0
	spawn_timer=0.0
	battle_income=0
	pending_cells.clear()
	spawn_queue.clear()
	ensure_infection_sources_clear()
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
	selected_rewards.clear()
	reward_choices.clear()
	events.clear()
	next_id = 1
	round_no = 1
	tier = 1
	xp = int(shop_rules.xp_per_round)
	max_funds = int(shop_rules.starting_funds)+int(shop_rules.income)
	money = max_funds
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
	make_wave()
	record("new_run", {"seed":seed_number,"rounds":rounds})

func available_cell_keys():
	return catalog.keys().filter(func(key):return experimental or not catalog[key].get("experimental",false))

func available_virus_keys():
	var keys=["basic","wave","jumper","hungry","swarmer","seeker","avoider"]
	if experimental: keys.append("pusher")
	return keys

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
	a.sale+=int(b.get("sale",1))-1
	a.max_hp += b.max_hp
	a.hp = a.max_hp
	a.rank += b.rank
	cells.erase(b)
	if a.rank == 3:
		queue_reward()
	rebuild_links()
	record("merge",{"key":a.key,"hp":a.hp,"rank":a.rank,"p":a.p})
	effect(a.p,Color("#f6de8d"),"Hug!",48)
	return true

func queue_reward():
	var pool: Array = []
	for key in available_cell_keys():
		if int(catalog[key].tier)==0:
			pool.append(key)
	var a = pool[rng.randi_range(0,pool.size()-1)]
	pool.erase(a)
	var b = pool[rng.randi_range(0,pool.size()-1)]
	reward_choices.append([a,b])

func choose_reward(index: int):
	if reward_choices.is_empty() or index < 0 or index > 1:
		return
	var chosen=reward_choices.pop_front()[index]
	rewards.append(chosen)
	selected_rewards.append(chosen)
	record("reward_chosen")

func purchase(index: int, p: Vector2, reward = false):
	if phase != "shop":
		return false
	var source = rewards if reward else offers
	if index < 0 or index >= source.size():
		return false
	var key = source[index]
	if not available_cell_keys().has(key): return false
	if not reward and money < int(shop_rules.buy_price):
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
		money-=int(shop_rules.buy_price)
		if catalog[key].category=="B":
			for c in cells:
				if c.key=="resonant_wall":
					c.max_hp+=constant_of(c,"healthIncrement",1)
					c.hp+=constant_of(c,"healthIncrement",1)
				if c.key=="resonant_buffer":
					item.max_hp+=constant_of(c,"healthIncrement",1)
					item.hp+=constant_of(c,"healthIncrement",1)
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

func draw_offer():
	var chosen_rewards=selected_rewards.filter(func(key):return available_cell_keys().has(key))
	if rng.randf()<float(shop_rules.reward_chance) and not chosen_rewards.is_empty():
		return chosen_rewards[rng.randi_range(0,chosen_rewards.size()-1)]
	var thresholds=shop_rules.tier_cdf[tier-1]
	var roll=rng.randf()
	var chosen_tier=1
	for i in range(thresholds.size()):
		chosen_tier=i+1
		if roll<float(thresholds[i]): break
	var pool=available_cell_keys().filter(func(key):return int(catalog[key].tier)==chosen_tier)
	# Current experimental toggle is retained; unsupported/disabled tiers cannot be drawn.
	if pool.is_empty():
		pool=available_cell_keys().filter(func(key):return int(catalog[key].tier)>0 and int(catalog[key].tier)<=tier)
	return pool[rng.randi_range(0,pool.size()-1)]

func fill_shop():
	while offers.size()<int(shop_rules.market_sizes[tier-1]):
		offers.append(draw_offer())

func roll_shop(pay = true):
	if pay and (money<int(shop_rules.refresh_price) or phase!="shop"): return
	if pay: money-=int(shop_rules.refresh_price)
	offers.clear()
	fill_shop()
	record("shop_roll")

func gain_xp(amount):
	if tier>=5: return false
	xp+=amount
	if xp>=int(rules.xp_thresholds[tier-1]):
		tier+=1
		return true
	return false

func buy_xp():
	if phase!="shop" or money<int(shop_rules.xp_price) or tier>=5: return false
	money-=int(shop_rules.xp_price)
	if gain_xp(1):
		fill_shop()
		last_message="Level %d · Capacity increased to %d cells" % [tier,capacity()]
	else:
		last_message="+1 XP · %d / %d to level %d" % [xp,int(rules.xp_thresholds[tier-1]),tier+1]
	record("xp",{"tier":tier,"xp":xp})
	return true

func stat_of(c, field):
	if tuning.get(c.key,{}).has(field): return float(tuning[c.key][field])
	var data=catalog[c.key]
	if int(c.rank)>=3 and data.get("elite",{}).has(field): return float(data.elite[field])
	return float(data.get(field,0))

func constant_of(c, field, fallback=0):
	var data=catalog[c.key]
	if int(c.rank)>=3 and data.get("elite_constants",{}).has(field): return float(data.elite_constants[field])
	return float(data.get("constants",{}).get(field,fallback))

func cell_by_id(id):
	for c in cells:
		if c.id==id:
			return c
	return {}

func endpoint_by_id(id):
	if id < -1:
		for b in blood:
			if -2-int(b.id)==id: return b
		return {}
	var cell=cell_by_id(id)
	if not cell.is_empty():return cell
	for v in viruses:
		if v.id==id:return v
	return {}

func core_endpoint(b):
	return -2-int(b.id)

func hit_core(b,v,attack_hp=-1.0):
	if v.jump:return
	if not b.alive:
		if attack_hp>=0:damage_virus(v,999,{"p":b.p,"cause":"core"})
		return
	var amount=float(v.hp) if attack_hp<0 else attack_hp
	amount=intercept_damage(core_endpoint(b),amount,{"kind":"virus","id":v.id,"p":v.p})
	if amount>0:
		b["hp"]=float(b.get("hp",1.0))-amount
		if b.hp<=0:
			b.alive=false
			effect(b.p,Color("#eb8f9d"),"",35)
			record("blood_lost",{"id":b.id,"p":b.p})
	else:record("core_protected",{"id":b.id,"p":b.p})
	damage_virus(v,999,{"p":b.p,"cause":"core"})

func rebuild_links():
	bonds.rebuild(self)

func network(id):
	var source=endpoint_by_id(id)
	if source.is_empty() or not source.alive:return []
	var found=[id]
	var cursor=0
	while cursor<found.size():
		var here=found[cursor]
		cursor+=1
		for l in links:
			var other=l.b if l.a==here else (l.a if l.b==here else -1)
			if other==-1 or found.has(other):
				continue
			var c=endpoint_by_id(other)
			if not c.is_empty() and c.alive:
				found.append(other)
	return found

func direct_neighbors(id):
	var found=[]
	var source=endpoint_by_id(id)
	if source.is_empty() or not source.alive:return found
	for link in links:
		var other=link.b if link.a==id else (link.a if link.b==id else -1)
		var body=endpoint_by_id(other)
		if other!=-1 and not body.is_empty() and body.alive and not found.has(other):found.append(other)
	return found

func ability_targets(provider):
	if provider.is_empty() or not provider.alive:return []
	var direct=provider.key in ["accelerator","swapper"]
	var ids=direct_neighbors(provider.id) if direct else network(provider.id)
	# Kinetic Bond includes itself; Connected auras explicitly use NotSelf.
	return ids.filter(func(id):return id!=provider.id or provider.key=="kinetic_bond")

func ability_reaches(provider,target_id):
	return ability_targets(provider).has(target_id)

func range_of(c):
	var r=stat_of(c,"range")*float(rules.scale)
	if c.key=="survivor_bomb": r+=float(c.get("radius_growth",0))*float(rules.scale)
	if c.key=="hungry_bomb": r+=float(c.get("radius_growth",0))*float(rules.scale)
	if c.key=="electromagnet": r+=float(c.charge)*constant_of(c,"conversionRate",2)*float(rules.scale)
	return r+float(c.get("range_bonus",0))

func speed_of(c):
	return stat_of(c,"speed")

func apply_radar(c, provider={}):
	c["range_bonus"]=(constant_of(provider,"rangeIncrement",20) if not provider.is_empty() else float(rules.radar_bonus))*float(rules.scale)
	c.range_buff=1.0+c.range_bonus/maxf(1,float(catalog[c.key].range)*float(rules.scale))

func interval_of(c):
	if tuning.get(c.key,{}).has("interval"): return float(tuning[c.key].interval)
	var interval=stat_of(c,"interval")
	if c.key=="gatling": return maxf(0.05,interval-constant_of(c,"reduction",0.25)*float(c.get("kills",0)))
	return interval

func make_wave():
	var plan=infection_plan.build(seed_value,round_no,available_virus_keys())
	source_center=Vector2.ZERO
	infection_sources=plan.positions
	source_emitters=plan.emitters
	wave=plan.wave

func begin_battle():
	if phase!="shop" or not reward_choices.is_empty():
		return
	ensure_infection_sources_clear()
	round_losses={"viruses":0,"core":0,"cells":0}
	physics.clear()
	blasts.clear()
	rebuild_links()
	bonds.lock(self)
	phase="battle"
	elapsed=0
	spawn_timer=0
	viruses.clear()
	particles=particles.filter(func(p):return p.get("setup",false))
	for p in particles: p.life=8.0
	battle_income=0
	pending_cells.clear()
	spawn_queue.clear()
	rebuild_links()
	for c in cells:
		c.start=c.p
		c.start_angle=c.angle
		c.cool=0.1
		c.contact=0
		c["friendly_stun"]=0.0
		c.range_buff=1.0
		c["range_bonus"]=0.0
		c.speed_buff=1.0
		c.orbit=c.p.angle()
		c.alive=true
		c.hp=c.max_hp
		c.food=0
		c["bullet_food"]=0
		c["kills"]=0
		c["distance_charge"]=0.0
		c["distance_health"]=0.0
		c["travel_x"]=c.p.x
		c["travel_y"]=c.p.y
		if c.key=="hungry_bomb": c["radius_growth"]=0.0
		if c.key=="greed_wall": c.hp+=constant_of(c,"conversionRate",2)*money
		c.charge=int(constant_of(c,"charge",2)) if c.key=="zapper" else 0
	for c in cells:
		for id in network(c.id):
			var n=cell_by_id(id)
			if n.get("key","")=="radar" and ability_reaches(n,c.id): apply_radar(c,n)
			if n.get("key","")=="accelerator" and ability_reaches(n,c.id): c.speed_buff=float(rules.accelerator_multiplier)
	spawn_queue=infection_plan.schedule(wave,source_emitters,rng)

	record("battle_start")

func make_infection_sources():
	make_wave()

# 70 units reserve the fully opened ink source plus a small membrane gap.
func source_position_clear(p):
	for b in blood:
		if b.alive and p.distance_to(b.p)<88.0: return false
	for c in cells:
		if not c.alive: continue
		if catalog[c.key].behavior=="wall":
			var local=(p-c.p).rotated(-c.angle)
			var nearest=local.clamp(Vector2(-43,-13),Vector2(43,13))
			if local.distance_to(nearest)<70.0: return false
		elif p.distance_to(c.p)<88.0: return false
	return true

func ensure_infection_sources_clear():
	# Original external sources keep their slots, even after player repositioning.
	pass

func spawn_virus(entry):
	if not available_virus_keys().has(entry.type): return
	var p=entry.get("p",infection_sources[entry.lane])
	var hp=float(tuning.get("virus:"+entry.type,{}).get("hp",2.0 if entry.type=="seeker" else 1.0))
	viruses.append({"id":next_id,"type":entry.type,"p":p,"hp":hp,"peak_hp":hp,"alive":true,
		"cool":0.0,"tag":0.0,"freeze":0.0,"age":0.0,"lived":0.0,"lifespan":12.0+rng.randf()*2.0,"jump":false,"phase":rng.randf()*TAU,
		"emerging":false,"exit":p,"spawn_position":p,"source_lane":entry.lane})
	next_id+=1

func spawn_eta(entry: Dictionary, index: int=0) -> float:
	return maxf(0.0,float(entry.due)-elapsed) if entry.has("due") else maxf(0.0,spawn_timer)+index*SPAWN_INTERVAL

func source_releasing(lane: int) -> bool:
	return spawn_queue.any(func(e):return e.lane==lane and spawn_eta(e)<=0.65) or viruses.any(func(v):return v.alive and v.get("source_lane",-1)==lane and v.get("age",1.0)<0.65)

func advance_spawns(delta: float):
	spawn_timer-=delta
	var pending=[]
	for entry in spawn_queue:
		if entry.has("due"):
			if float(entry.due)<=elapsed+0.000001: spawn_virus(entry)
			else: pending.append(entry)
		elif spawn_timer<=0:
			spawn_virus(entry)
			spawn_timer=SPAWN_INTERVAL
		else: pending.append(entry)
	spawn_queue=pending

func nearest_virus(p: Vector2, reach: float=10000.0) -> Dictionary:
	# Distances are nonnegative and the original comparison is strict (<).
	# A nonpositive radius therefore cannot select any target.
	if reach<=0.0:return {}
	var best={}
	var dist=reach
	for v: Dictionary in viruses:
		if not v.alive: continue
		var position: Vector2=v.p
		var d: float=p.distance_to(position)
		if d<dist:
			dist=d
			best=v
	return best

func nearest_blood(p: Vector2) -> Dictionary:
	var best: Dictionary={}
	var dist: float=INF
	for b: Dictionary in blood:
		if not b.alive:continue
		var position: Vector2=b.p
		var distance: float=p.distance_squared_to(position)
		if distance<dist:
			dist=distance
			best=b
	return best

func effect(p, color, label="", radius=30.0):
	effects.append({"p":p,"color":color,"text":label,"r":radius,"life":0.8,"max":0.8})

func shoot(c, direction, origin=Vector2.INF, split=false):
	var p=c.p if origin==Vector2.INF else origin
	record("attack_fired",{"id":c.id,"p":p,"direction":direction.normalized(),"key":c.key})
	var radius=5.0
	if c.key=="cannon":
		var count=0
		for n in cells:
			if catalog[n.get("key","")].category=="B": count+=1
		radius+=count*0.65
	particles.append({"kind":"bullet","p":p,"v":direction.normalized()*float(rules.bullet_speed),
		"life":4.0,"r":radius,"owner":c.id,"split":split})
	effect(p,Color(catalog[c.key].color),"",10)

func bond_path(start_id,end_id):
	# Read-only provenance for a transfer already chosen by network().
	var queue=[start_id]
	var paths={start_id:[endpoint_by_id(start_id).p]}
	while not queue.is_empty():
		var id=queue.pop_front()
		if id==end_id: return paths[id]
		for link in links:
			var next=-1
			if link.a==id: next=link.b
			elif link.b==id: next=link.a
			if next==-1 or paths.has(next): continue
			var cell=endpoint_by_id(next)
			if cell.is_empty(): continue
			paths[next]=paths[id]+[cell.p]
			queue.append(next)
	return []

func heal(c, amount, source={}):
	if not c.alive: return
	c.hp+=amount
	c.flash=0.3
	effect(c.p,Color("#a3e4b6"),"+"+str(amount)+" Health",24)
	record("heal",{"id":c.id,"hp":c.hp,"p":c.p,"amount":amount,"from":source.get("p",c.p)})

# SCAPEGOAT_CHAIN targets Connected (whole component), excluding itself.
# One live guard absorbs at most its HP; overflow reaches the original target.
func intercept_damage(target_id,amount,source={}):
	for id in network(target_id):
		var guard=cell_by_id(id)
		if id==target_id or guard.is_empty() or not guard.alive or guard.key!="bodyguard":continue
		var absorbed=minf(maxf(0,guard.hp),amount)
		if absorbed<=0:continue
		record("transfer",{"path":bond_path(target_id,id),"amount":absorbed})
		damage_cell(guard,absorbed,true,source)
		return amount-absorbed
	return amount

func damage_cell(c, amount, redirected=false, source={}):
	if not c.alive: return
	if experimental and c.key=="tag_proof" and source.get("kind","")=="virus":
		for v in viruses:
			if v.id==source.get("id",-1) and v.tag>0: return
	if not redirected:
		amount=intercept_damage(c.id,amount,source)
	if amount<=0:return
	c.hp-=amount
	c.flash=0.25
	record("damage",{"id":c.id,"hp":c.hp,"p":c.p,"amount":amount,"source_kind":source.get("kind","unknown"),"source_id":source.get("id",-1),"from":source.get("p",c.p)})
	if c.key=="impact_wall":
		var dir=Vector2.RIGHT.rotated(c.angle)
		shoot(c,dir,c.p+dir*42)
		shoot(c,-dir,c.p-dir*42)
	if c.hp>0: return
	c.alive=false
	effect(c.p,Color(catalog[c.key].color),"",40)
	if c.key in ["bomb","survivor_bomb","hungry_bomb"]:
		record("camera_blast",{"p":c.p})
		start_blast(c.p,range_of(c),1.0,600.0,c.id)
	if c.key=="bandage":
		for other in cells:
			if other.alive and c.p.distance_to(other.p)<range_of(c):
				heal(other,constant_of(c,"healAmount",1),c)
	record("cell_rest",{"id":c.id,"p":c.p})

func damage_virus(v, amount, source={}):
	if not v.alive or (v.jump and source.get("cause","")!="expiry"): return
	var prior_hp=v.hp
	v.hp-=amount
	record("virus_hit",{"id":v.id,"p":v.p,"amount":amount,"from":source.get("p",v.p),"cause":source.get("cause","contact")})
	if v.hp>0: return
	v.alive=false
	experiments.virus_death(self,v)
	var shooter=cell_by_id(source.get("owner",-1))
	if experimental and shooter.get("key","")=="gatling": shooter["kills"]=int(shooter.get("kills",0))+1
	particles.append({"kind":"food","p":v.p,"v":Vector2.ZERO,"life":float(rules.protein_lifetime),"r":4.0,"owner":-1})
	effect(v.p,Color("#d4b8e7"),"",20)
	var core=nearest_blood(v.p)
	var key_threat=v.type=="seeker" or v.get("peak_hp",prior_hp)>=3 or (not core.is_empty() and core.p.distance_to(v.p)<80)
	record("virus_defeated",{"type":v.type,"id":v.id,"p":v.p,"key_threat":key_threat})

func push_object(object,offset,kind,origin):
	physics.impulse(self,object,offset*physics.parameter(self,object,"impulse_scale"),origin)
	if offset.length_squared()>0:
		record("pushed",{"id":object.id,"p":object.p,"kind":kind,"from":origin,"direction":offset.normalized()})

func contains_cell(c, p, extra=0.0):
	var local=(p-c.p).rotated(-c.angle)
	if catalog[c.key].behavior=="wall":
		return absf(local.x)<43+extra and absf(local.y)<13+extra
	return local.length()<18+extra

func update(delta: float):
	var movement_delta: float=delta*float(rules.get("movement_multiplier",1.0))
	for e: Dictionary in effects: e.life-=delta
	effects=effects.filter(func(e): return e.life>0)
	for c: Dictionary in cells: c.flash=maxf(0,c.flash-delta)
	if phase in ["shop","battle"]: step_blood(delta)
	if phase=="shop": rebuild_links()
	if phase!="battle": return
	elapsed+=delta
	advance_spawns(delta)
	proteins.route_food(self,delta)
	var has_network_buffs=false
	for provider: Dictionary in cells:
		if provider.alive and provider.key in ["radar","accelerator"]:
			has_network_buffs=true
			break
	for c: Dictionary in cells:
		if not c.alive: continue
		c.range_buff=1.0
		c["range_bonus"]=0.0
		c.speed_buff=1.0
		for id in (network(c.id) if has_network_buffs else []):
			var provider=cell_by_id(id)
			if provider.get("key","")=="radar" and ability_reaches(provider,c.id): apply_radar(c,provider)
			if provider.get("key","")=="accelerator" and ability_reaches(provider,c.id): c.speed_buff=float(rules.accelerator_multiplier)
		proteins.tick(self,c,delta)
		experiments.tick(self,c,delta)
		c.cool-=delta
		c.contact=maxf(0,c.contact-delta)
		c["friendly_stun"]=maxf(0,float(c.get("friendly_stun",0))-delta)
		var d: Dictionary=catalog[c.key]
		var velocity: Vector2=Vector2.ZERO
		var reach: float=range_of(c)
		var target: Dictionary=nearest_virus(c.p,reach)
		if c.key=="tag_splitter":
			var distance=reach if target.is_empty() else c.p.distance_to(target.p)
			for p: Dictionary in particles:
				if p.life>0 and p.kind=="tag" and p.p.distance_to(c.p)<distance:
					target={"p":p.p}
					distance=p.p.distance_to(c.p)
		if target.is_empty() and d.category=="T" and reach>0:
			for candidate: Dictionary in viruses:
				if candidate.alive and candidate.tag>0 and c.p.distance_to(candidate.p)<reach*2:
					target=candidate
					break
		if d.behavior=="forward" or d.behavior=="drop":
			velocity=Vector2.RIGHT.rotated(c.angle)*speed_of(c)*3
		elif d.behavior=="seek":
			# Tagged targets can be detected at twice the normal distance.
			if target.is_empty():
				for v: Dictionary in viruses:
					if v.alive and v.tag>0 and c.p.distance_to(v.p)<reach*2:
						target=v
						break
			if not target.is_empty(): velocity=c.p.direction_to(target.p)*speed_of(c)*3
		elif d.behavior=="orbit":
			var radius: float=maxf(100,c.start.length())
			if c.friendly_stun<=0:c.orbit-=speed_of(c)*3/radius*movement_delta
			var desired: Vector2=Vector2.from_angle(c.orbit)*radius
			velocity=(desired-c.p).limit_length(speed_of(c)*3)
		if c.get("launch_remaining",0.0)>0:
			velocity=Vector2.RIGHT.rotated(c.angle)*150.0
			c.launch_remaining=maxf(0,c.launch_remaining-delta)
		if c.friendly_stun>0: velocity=Vector2.ZERO
		physics.drive(c,velocity*float(rules.movement_multiplier)*float(c.speed_buff))
		if c.cool<=0:
			c.cool=maxf(0.05,interval_of(c))
			match d.behavior:
				"shoot":
					var feeder=experiments.feed_target(self,c)
					if not feeder.is_empty(): shoot(c,feeder.p-c.p)
					elif not target.is_empty(): shoot(c,target.p-c.p)
				"sniper":
					var dir: Vector2=Vector2.RIGHT.rotated(c.angle)
					var feeder=experiments.feed_target(self,c)
					if not feeder.is_empty(): shoot(c,dir)
					for candidate: Dictionary in ([] if not feeder.is_empty() else viruses):
						if candidate.alive and c.p.distance_to(candidate.p)<reach and absf(dir.angle_to(candidate.p-c.p))<0.20:
							shoot(c,dir)
							break
				"heal":
					for other: Dictionary in cells:
						if other.alive and other.p.distance_to(c.p)<reach: heal(other,constant_of(c,"healAmount",1),c)
				"push":
					record("attack_fired",{"id":c.id,"p":c.p,"direction":Vector2.ZERO,"key":c.key})
					effect(c.p,Color("#f7dec3"),"",reach)
					for v: Dictionary in viruses:
						if v.alive and v.p.distance_to(c.p)<reach: push_object(v,(v.p-c.p).normalized()*30,"virus",c.p)
					for other: Dictionary in cells:
						if other.id!=c.id and other.alive and other.p.distance_to(c.p)<reach: push_object(other,(other.p-c.p).normalized()*20,"cell",c.p)
				"drop":
					particles.append({"kind":"tag","p":c.p,"v":Vector2.ZERO,"life":8.0,"r":5.0,"owner":c.id})
				"spray":
					var angle=c.angle+rng.randf_range(-PI/2,PI/2)
					particles.append({"kind":"tag","p":c.p,"v":Vector2.from_angle(angle)*95,"life":reach/95,"r":5.0,"owner":c.id})
		if c.key=="magnet":
			for v: Dictionary in viruses:
				if v.alive and v.p.distance_to(c.p)<reach: physics.accelerate(self,v,v.p.direction_to(c.p)*60*float(rules.movement_multiplier),delta)
		if c.key=="generator":
			if c.food>=constant_of(c,"proteinAmount",8):
				c.food-=int(constant_of(c,"proteinAmount",8))
				var increment=int(constant_of(c,"increment",8))
				c.charge+=increment
				record("generator_charged",{"id":c.id,"p":c.p,"amount":increment})
		if c.charge>0 and c.key!="electromagnet":
			conduct(c)
	for c: Dictionary in pending_cells:
		if cells.size()<int(rules.produced_cell_limit): cells.append(c)
	pending_cells.clear()
	var core_positions: PackedVector2Array=[]
	for b: Dictionary in blood:core_positions.append(b.p)
	for v: Dictionary in viruses:
		if not v.alive: continue
		v["lived"]=float(v.get("lived",0))+delta
		if v.lived>float(v.get("lifespan",14.0)):
			damage_virus(v,maxf(1,v.hp),{"p":v.p,"cause":"expiry"})
			continue
		v.age+=delta
		v.cool=maxf(0,v.cool-delta)
		if v.tag>0 and v.tag<=delta: record("tag_ended",{"id":v.id,"p":v.p})
		if v.freeze>0 and v.freeze<=delta: record("thawed",{"id":v.id,"p":v.p})
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
		var destination: Dictionary=nearest_blood_at(v.p,core_positions)
		if destination.is_empty():
			if gym_mode: continue
			finish(false)
			return
		var target_pos: Vector2=destination.p
		var target_key: String="core:"+str(destination.id)
		if v.type=="seeker":
			var nearest: float=15.0*26.0/3.5
			for c: Dictionary in cells:
				if c.alive and c.p.distance_to(v.p)<nearest:
					target_pos=c.p
					target_key="cell:"+str(c.id)
					nearest=c.p.distance_to(v.p)
		if v.type=="seeker" and v.get("visual_target","")!=target_key:
			record("virus_target",{"id":v.id,"p":v.p,"target":target_pos})
		v.visual_target=target_key
		var dir: Vector2=v.p.direction_to(target_pos)
		var speed: float=float(rules.virus_speed)
		speed*=float(rules.get("virus_movement_multiplier",1.0))
		speed*=float(tuning.get("virus:"+v.type,{}).get("speed_multiplier",1.0))
		v.visual_avoiding=false
		if v.type=="avoider":
			var avoid={};var distance=15.0*26.0/3.5
			for c: Dictionary in cells:
				var d=v.p.distance_to(c.p)
				if c.alive and d<distance:avoid=c;distance=d
			if not avoid.is_empty() and v.freeze<=0:
				var force=avoid.p.direction_to(v.p)*150.0*virus_motion.multiplier(self,v)/(PI*1.75*1.75)*physics.mass(self,v)
				physics.accelerate(self,v,force,delta)
				v.visual_avoiding=true
			speed*=20.0/15.0
		if v.type=="seeker":speed*=25.0/15.0
		if v.type=="swarmer":update_swarm_attraction(v,delta)
		v.visual_heading=dir
		if not virus_motion.tick(self,v,dir,delta):
			physics.drive(v,dir*speed*float(rules.movement_multiplier) if v.freeze<=0 else Vector2.ZERO)
	physics.step(self,delta)
	join_swarm_contacts()
	for pair: Vector2i in physics.contacts:
		var a=endpoint_by_id(pair.x);var b=endpoint_by_id(pair.y)
		if a.is_empty() or b.is_empty() or a.has("type") or b.has("type"):continue
		for body in [a,b]:
			if body.has("key") and float(body.get("friendly_stun",0))<=0:
				body.friendly_stun=float(rules.get("friendly_collision_stun",0.5))
	resolve_cell_contacts()
	advance_blasts(delta)
	for p: Dictionary in particles:
		if p.life<=0: continue
		p.life-=delta
		var previous=p.p
		p.p+=p.v*movement_delta
		if p.kind=="bullet":
			resolve_bullet(p,previous,p.p)
		elif p.kind=="tag":
			for v: Dictionary in viruses:
				if v.alive and v.p.distance_to(p.p)<17:
					v.tag=4
					v.freeze=1
					record("tagged",{"id":v.id,"p":v.p,"from":p.p,"owner":p.owner})
					p.life=0
					break
	particles=particles.filter(func(p): return p.life>0)
	viruses=viruses.filter(func(v): return v.alive)
	if gym_mode: return
	if blood.filter(func(b): return b.alive).is_empty():
		finish(false)
	elif spawn_queue.is_empty() and viruses.is_empty() and blasts.is_empty() and effects.is_empty():
		if round_no>=target_rounds: finish(true)
		else: phase="recap"

# Auto Immune PreSolve emits damage on every touching physics step, not only
# BeginContact. Snapshot ALL attackers before resolving any of this step's hits.
func resolve_cell_contacts():
	var bodies={}
	for c in cells:
		if c.alive:bodies[int(c.id)]=c
	for v in viruses:
		if v.alive and not v.jump and not v.get("emerging",false):bodies[int(v.id)]=v
	for b in blood:
		if b.alive:bodies[core_endpoint(b)]=b
	var hits=[]
	for pair: Vector2i in physics.contacts:
		if not bodies.has(pair.x) or not bodies.has(pair.y):continue
		var a=bodies[pair.x];var b=bodies[pair.y]
		if a.has("type")==b.has("type"):continue
		var v=a if a.has("type") else b
		var c=b if a.has("type") else a
		hits.append({"cell":c,"virus":v,"cell_hp":c.get("hp",1.0) if c.has("key") else 999.0,"virus_hp":v.hp})
	for hit in hits:
		if not hit.cell.has("key"):
			hit_core(hit.cell,hit.virus,hit.virus_hp)
			continue
		damage_cell(hit.cell,hit.virus_hp,false,{"kind":"virus","id":hit.virus.id,"p":hit.virus.p})
		damage_virus(hit.virus,hit.cell_hp,{"p":hit.cell.p,"cause":"contact"})

func start_blast(position,reach,damage=1.0,force=600.0,owner=-1,immune_only=false):
	var duration=maxf(0.02,reach/float(rules.scale)*0.02)
	var visual={"p":position,"color":Color("#f9b8d1") if damage>0 else Color("#a5e2f0"),"text":"","r":0.0,"front":true,"life":duration,"max":duration}
	effects.append(visual)
	blasts.append({"p":position,"reach":reach,"radius":0.0,"duration":duration,"age":0.0,"hit":{},"immune_only":immune_only,"damage":damage,"force":force,"owner":owner,"visual":visual})

func advance_blasts(delta):
	# Iterate a snapshot: a killed bomb starts a distinct front next step.
	for blast in blasts.duplicate():
		blast.age+=delta
		blast.radius=minf(blast.reach,blast.reach*blast.age/blast.duration)
		blast.visual.r=blast.radius
		for body in cells+viruses:
			if blast.immune_only and body.has("type"):continue
			if not body.alive or blast.hit.has(body.id) or body.id==blast.owner:continue
			if body.has("type") and body.jump:continue
			# Distance to the fixture, including rotated rectangular walls.
			if not contains_cell(body,blast.p,blast.radius) if body.has("key") else body.p.distance_to(blast.p)>blast.radius+physics.radius(body):continue
			blast.hit[body.id]=true
			# Force 600 / 400 is integrated for one original fixed physics step.
			physics.impulse(self,body,blast.p.direction_to(body.p)*blast.force*(26.0/3.5)/60.0,blast.p)
			if blast.damage>0:
				if body.has("type"):damage_virus(body,blast.damage,{"p":blast.p,"cause":"blast"})
				else:damage_cell(body,blast.damage,false,{"kind":"cell","id":blast.owner,"p":blast.p})
		blast.visual.life=maxf(0.001,blast.duration-blast.age)
	blasts=blasts.filter(func(b):return b.age<b.duration)

# Earliest fraction of a swept projectile against actual circle / rotated box.
func projectile_fraction(body,from,to,radius):
	var start=from-body.p;var motion=to-from
	if physics.is_box(self,body):
		start=start.rotated(-float(body.get("angle",0)))
		motion=motion.rotated(-float(body.get("angle",0)))
		var half=Vector2(43,13)+Vector2.ONE*radius
		var entry=0.0;var leave=1.0
		for axis in range(2):
			if absf(motion[axis])<0.000001:
				if absf(start[axis])>half[axis]:return INF
			else:
				var a=(-half[axis]-start[axis])/motion[axis]
				var b=(half[axis]-start[axis])/motion[axis]
				entry=maxf(entry,minf(a,b));leave=minf(leave,maxf(a,b))
				if entry>leave:return INF
		return entry
	var reach=physics.radius(body)+radius
	var c=start.length_squared()-reach*reach
	if c<=0:return 0.0
	var a=motion.length_squared()
	if a<0.000001:return INF
	var b=start.dot(motion);var discriminant=b*b-a*c
	if discriminant<0:return INF
	var t=(-b-sqrt(discriminant))/a
	return t if t>=0 and t<=1 else INF

func resolve_bullet(p,from,to):
	var target={};var nearest=INF
	for body in cells+viruses:
		if not body.alive or body.id==p.owner:continue
		if body.has("type"):
			if body.jump:continue
		elif body.key not in ["bullet_wall","mortar","seeker_factory"]:continue
		elif body.key=="bullet_wall" and p.get("split",false):continue
		elif body.key=="seeker_factory" and (not experimental or int(body.get("bullet_food",0))>=2):continue
		var t=projectile_fraction(body,from,to,float(p.r))
		if t<nearest:nearest=t;target=body
	if target.is_empty():return
	p.p=from.lerp(to,nearest);p.life=0
	if target.has("type"):
		damage_virus(target,1,{"p":from,"cause":"bullet","owner":p.owner})
	elif target.key=="bullet_wall":
		var dir=p.v.normalized()
		shoot(target,dir.rotated(-0.18),target.p+dir*48,true)
		shoot(target,dir.rotated(0.18),target.p+dir*48,true)
		record("bullet_split",{"p":target.p,"direction":dir})
	else:
		if target.key=="mortar":target.food+=1
		else:target["bullet_food"]=int(target.get("bullet_food",0))+1
		record("protein_eaten",{"id":target.id,"p":target.p,"from":p.p,"kind":"bullet"})

func update_swarm_attraction(v,delta):
	var attached=[]
	for link in links:
		if not link.get("swarm",false):continue
		var other=link.b if link.a==v.id else (link.a if link.b==v.id else -1)
		var body=endpoint_by_id(other)
		if not body.is_empty() and body.alive:attached.append(body)
	var host=-1 if attached.is_empty() else attached[0].id
	if v.get("host",-1)!=host:
		record("virus_attachment",{"id":v.id,"p":v.p,"old_host":v.get("host",-1),"host":host})
	v.host=host
	if host!=-1 or v.freeze>0:return
	var nearby=viruses.filter(func(other):return other.alive and other.id!=v.id and not other.jump and v.p.distance_to(other.p)<60.0*26.0/3.5)
	nearby.sort_custom(func(a,b):return v.p.distance_squared_to(a.p)<v.p.distance_squared_to(b.p))
	for other in nearby.slice(0,9):
		physics.accelerate(self,v,v.p.direction_to(other.p)*25.0*virus_motion.multiplier(self,v)/(PI*1.75*1.75)*physics.mass(self,v),delta)

func join_swarm_contacts():
	for v in viruses:
		if not v.alive or v.type!="swarmer" or v.jump or v.get("host",-1)>=0:continue
		for other in viruses:
			if not other.alive or other==v or other.jump:continue
			if links.any(func(l):return (l.a==v.id and l.b==other.id) or (l.b==v.id and l.a==other.id)):continue
			if v.p.distance_to(other.p)>physics.radius(v)+physics.radius(other)+0.02:continue
			links.append({"a":v.id,"b":other.id,"owner":v.id,"rest":v.p.distance_to(other.p),"offset":(other.p-v.p).rotated(-float(v.get("angle",0))),"relative_angle":float(other.get("angle",0))-float(v.get("angle",0)),"locked":true,"swarm":true})
			record("virus_attachment",{"id":v.id,"p":v.p,"old_host":-1,"host":other.id})
			v.host=other.id

func conduct(c):
	# Provisional graph: objects within charge_range conduct one charge per victim.
	var points=[c.p]
	var paths=[[c.p]]
	var seen={}
	var cursor=0
	while cursor<points.size() and cursor<200:
		var p=points[cursor]
		cursor+=1
		for v in viruses:
			if v.alive and not v.jump and p.distance_to(v.p)<float(rules.charge_range):
				c.charge-=1
				effects.append({"p":p,"end":v.p,"color":Color("#fff3a9"),"text":"","r":0,"life":0.35,"max":0.35})
				damage_virus(v,999,{"p":p,"cause":"electric"})
				record("discharge",{"path":paths[cursor-1]+[v.p],"source":c.id,"target":v.id})
				record("charge_kill",{"source":c.id})
				return
		for other in cells:
			if other.alive and not seen.has(other.id) and p.distance_to(other.p)<float(rules.charge_range):
				seen[other.id]=true
				points.append(other.p)
				paths.append(paths[cursor-1]+[other.p])
		for i in range(particles.size()):
			var particle=particles[i]
			if particle.life>0 and not seen.has(-i-1) and p.distance_to(particle.p)<float(rules.charge_range):
				seen[-i-1]=true
				points.append(particle.p)
				paths.append(paths[cursor-1]+[particle.p])

func next_budget():
	return mini(max_funds+int(shop_rules.income),int(shop_rules.max_income))+battle_income

func next_round():
	if phase!="recap": return
	physics.clear()
	blasts.clear()
	cells=cells.filter(func(c):return not c.get("temporary",false))
	links=links.filter(func(l):return not endpoint_by_id(l.a).is_empty() and not endpoint_by_id(l.b).is_empty())
	for c in cells:
		if c.key=="bank" and c.alive: c.sale+=int(constant_of(c,"incomeIncrement",1))
		if c.key=="survivor_bomb" and c.alive:
			c["radius_growth"]=float(c.get("radius_growth",0))+constant_of(c,"blastIncrement",8)
			record("permanent_growth",{"id":c.id,"p":c.p,"amount":8})
		c.p=c.start
		c.angle=c.start_angle
		c.range_buff=1.0
		c["range_bonus"]=0.0
		c.hp=c.max_hp
		c.alive=true
		c.charge=int(constant_of(c,"charge",2)) if c.key=="zapper" else 0
	# Capture all exchanges before modifying persistent health.
	var exchanges=[]
	for c in cells:
		if c.key!="swapper": continue
		var neighbors=ability_targets(c)
		neighbors.sort_custom(func(a,b):return endpoint_by_id(a).p.distance_squared_to(c.p)<endpoint_by_id(b).p.distance_squared_to(c.p))
		for id in neighbors:
			var other=cell_by_id(id)
			if other.is_empty():continue
			exchanges.append([c,other,c.max_hp,other.max_hp])
			break
	for swap in exchanges:
		swap[0].max_hp=swap[3]
		swap[0].hp=swap[3]
		swap[1].max_hp=swap[2]
		swap[1].hp=swap[2]
		record("swap",{"a":swap[0].id,"b":swap[1].id,"p":swap[0].p,"q":swap[1].p,"before_a":swap[2],"after_a":swap[3],"before_b":swap[3],"after_b":swap[2]})
	round_no+=1
	max_funds=mini(max_funds+int(shop_rules.income),int(shop_rules.max_income))
	money=max_funds+battle_income
	battle_income=0
	phase="shop"
	particles.clear()
	effects.clear()
	gain_xp(int(shop_rules.xp_per_round))
	if not frozen: roll_shop(false)
	frozen=false
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
			if a.is_empty() or b.is_empty() or not a.alive or not b.alive: continue
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

var web_core_normals: Array[Vector2]=[]
func step_blood(delta):
	# Dragging retains the original native path. Otherwise batch the identical
	# force integration and all eight overlap passes in the browser JIT.
	if blood_drag<0 and physics.get("web_kernel")!=null:
		step_blood_web(delta)
		return
	var count=maxi(1,int(ceil(minf(delta,0.1)*120)))
	var dt: float=minf(delta,0.1)/count
	var config=rules.blood_elasticity
	for step in range(count):
		# Translate the living cluster uniformly: centering must not compress its springs.
		if blood_drag<0:
			var center: Vector2=Vector2.ZERO
			var living=0
			for b in blood:
				if b.alive: center+=b.p; living+=1
			if living>0:
				center/=living
				var drift=rules.blood_drift
				var rate: float=float(drift.speed)/maxf(1,float(drift.slow_radius))
				var offset: Vector2=center*(exp(-rate*dt)-1.0)
				for b in blood:
					if b.alive: b.p+=offset
		var forces: Array[Vector2]=[]
		forces.resize(blood.size());forces.fill(Vector2.ZERO)
		for link in blood_links:
			var a=blood[link.a]
			var b=blood[link.b]
			if a.is_empty() or b.is_empty() or not a.alive or not b.alive: continue
			var offset: Vector2=b.p-a.p
			var distance: float=offset.length()
			if distance<0.001: continue
			var force: Vector2=offset/distance*(distance-26.0)*float(config.stiffness)
			forces[int(link.a)]+=force
			forces[int(link.b)]-=force
		for i in range(blood.size()):
			if not blood[i].alive: continue
			var velocity: Vector2=blood_velocity.get(i,Vector2.ZERO)
			velocity=(velocity+forces[i]*dt)*exp(-float(config.damping)*dt)
			velocity=velocity.limit_length(650)
			if i==blood_drag:
				var next: Vector2=blood[i].p.move_toward(blood_target,650*dt)
				velocity=(next-blood[i].p)/maxf(dt,0.00001)
			blood[i].p=(blood[i].p+velocity*dt).clamp(Vector2(-550,-300),Vector2(550,280))
			blood_velocity[i]=velocity
		# Snapshot positions once; keep the same pair order and all eight solver passes.
		# Array[Vector2] avoids repeated Dictionary lookup inside the hot pair loop.
		var positions: Array[Vector2]=[]
		var alive: Array[bool]=[]
		for b in blood:
			positions.append(b.p)
			alive.append(b.alive)
		for iteration in range(8):
			for i in range(positions.size()):
				if not alive[i]: continue
				for j in range(i+1,positions.size()):
					if not alive[j]: continue
					var offset: Vector2=positions[j]-positions[i]
					if offset.length_squared()>=676.0:continue
					var distance: float=offset.length()
					if distance>=26: continue
					var normal: Vector2=offset/distance if distance>0.001 else Vector2.RIGHT.rotated(i*2.4)
					var wa: float=0.0 if i==blood_drag else 1.0
					var wb: float=0.0 if j==blood_drag else 1.0
					var correction: Vector2=normal*(26-distance)/(wa+wb)
					positions[i]-=correction*wa
					positions[j]+=correction*wb
		for i in range(blood.size()): blood[i].p=positions[i]

func step_blood_web(delta):
	var living=false
	for b: Dictionary in blood:
		if b.alive:living=true;break
	if not living:return
	var count=maxi(1,int(ceil(minf(delta,0.1)*120)))
	var dt: float=minf(delta,0.1)/count
	while web_core_normals.size()<blood.size():web_core_normals.append(Vector2.RIGHT.rotated(web_core_normals.size()*2.4))
	var rows=[];var edges=[]
	for i in range(blood.size()):
		var b: Dictionary=blood[i];var velocity: Vector2=blood_velocity.get(i,Vector2.ZERO)
		rows.append([b.p.x,b.p.y,b.alive,velocity.x,velocity.y,web_core_normals[i].x,web_core_normals[i].y])
	for link in blood_links:edges.append([link.a,link.b])
	var rate=float(rules.blood_drift.speed)/maxf(1,float(rules.blood_drift.slow_radius))
	var payload=JSON.stringify([rows,edges,count,dt,exp(-rate*dt)-1.0,float(rules.blood_elasticity.stiffness),exp(-float(rules.blood_elasticity.damping)*dt)],"",true,true)
	var result=JavaScriptBridge.js_buffer_to_packed_byte_array(physics.web_kernel.coreStep(payload)).to_float32_array()
	for i in range(blood.size()):
		blood[i].p=Vector2(result[i*4],result[i*4+1])
		if blood[i].alive:blood_velocity[i]=Vector2(result[i*4+2],result[i*4+3])

func nearest_blood_at(p: Vector2,positions: PackedVector2Array) -> Dictionary:
	var best: Dictionary={}
	var distance: float=INF
	for i in range(positions.size()):
		var candidate: float=p.distance_squared_to(positions[i])
		if candidate<distance and blood[i].alive:
			distance=candidate
			best=blood[i]
	return best
