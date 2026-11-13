extends RefCounted
const Ref=preload("res://scripts/reference_physics.gd")
# Rules marked provisional are centralized in data/assumptions.json.
var shop_rules: Dictionary
var selected_rewards: Array = []
var max_funds = 3
var bonds=preload("res://scripts/bond_system.gd").new()
var physics=preload("res://scripts/body_physics.gd").new()
var tuning={}
var training_mode=-1 # -1 preserves legacy saves and explicit Gym setup.
var experimental=false
var experiments=preload("res://scripts/experimental_system.gd").new()
var virus_motion=preload("res://scripts/virus_motion.gd").new()
var electricity=preload("res://scripts/electricity.gd").new()
var proteins=preload("res://scripts/protein_system.gd").new()
var pending_cells=[]
var _projectile_grid_active=false
var _projectile_grid={}
var _projectile_bodies=[]
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
	target_rounds = [6,10,12,12][training_mode] if training_mode>=0 else rounds
	if training_mode>=0:experimental=true
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
	for i in range([14,30,30,30][training_mode] if training_mode>=0 else int(rules.start_blood)):
		blood.append({"p":sites[i],"alive":true,"id":i})
	rebuild_blood_links()
	roll_shop(false)
	make_wave()
	record("new_run", {"seed":seed_number,"rounds":rounds})

func available_cell_keys():
	return catalog.keys().filter(func(key):
		if training_mode<0:return experimental or not catalog[key].get("experimental",false)
		var id=int(catalog[key].get("reference_id",-1))
		if training_mode==3:return true
		if id in [47,48,49,50,51]:return false
		if training_mode<=2 and id in [15,38,41,40]:return false
		if training_mode<=1 and id in [6,34,32,35,33]:return false
		return true)

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
	if phase != "shop" or not cells.has(a) or not cells.has(b) or not compatible(a,b):
		return false
	# The ordinary participant survives regardless of drag direction.
	if a.key=="wildcard":
		var donor=a
		a=b
		b=donor
	var copies=int(a.get("copies",a.rank))+int(b.get("copies",b.rank))
	var permanent_radius=float(a.get("radius_growth",0)) if a.key=="survivor_bomb" else 0.0
	permanent_radius+=float(b.get("radius_growth",0)) if b.key=="survivor_bomb" else 0.0
	a.sale+=int(b.get("sale",1))-1
	a.max_hp += b.max_hp
	a.hp = a.max_hp
	a.rank = mini(3,int(a.rank)+int(b.rank))
	a["copies"]=copies
	if a.key=="survivor_bomb":a["radius_growth"]=permanent_radius
	cells.erase(b)
	if a.rank == 3:
		queue_reward()
	rebuild_links()
	record("merge",{"id":a.id,"key":a.key,"hp":a.hp,"rank":a.rank,"p":a.p})
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
	# Validate placement before allocating an ID: a refused purchase is inert.
	var item = {"id":-1,"key":key,"rank":1}
	var recipient = {}
	for c in cells:
		if compatible(c,item) and c.rank+item.rank<=3:
			if recipient.is_empty() or c.p.distance_to(p)<recipient.p.distance_to(p):
				recipient=c
	var direct = not recipient.is_empty() and (cells.size()>=capacity() or recipient.p.distance_to(p)<44)
	if cells.size()>=capacity() and not direct:
		last_message = "No room. Merge cells or level up."
		return false
	item = make_cell(key,p)
	var purchase_buffs=[]
	if not reward:
		money-=int(shop_rules.buy_price)
	if catalog[key].category=="B":
		for c in cells:
			if c.key=="resonant_wall":
				c.max_hp+=constant_of(c,"healthIncrement",1)
				c.hp+=constant_of(c,"healthIncrement",1)
				purchase_buffs.append({"source_id":item.id,"id":c.id,"amount":constant_of(c,"healthIncrement",1)})
			if c.key=="resonant_buffer":
				item.max_hp+=constant_of(c,"healthIncrement",1)
				item.hp+=constant_of(c,"healthIncrement",1)
				purchase_buffs.append({"source_id":c.id,"id":item.id,"amount":constant_of(c,"healthIncrement",1)})
	source.remove_at(index)
	cells.append(item)
	if direct:
		merge(recipient,item)
	for bonus in purchase_buffs:
		# Direct merge may consume either participant (Wildcard swaps the survivor).
		for field in ["source_id","id"]:
			if cell_by_id(bonus[field]).is_empty() and direct:
				bonus[field]=item.id if not cell_by_id(item.id).is_empty() else recipient.id
		var provider=cell_by_id(bonus.source_id)
		var receiver=cell_by_id(bonus.id)
		if bonus.amount>0 and not provider.is_empty() and not receiver.is_empty():
			bonus["from"]=provider.p
			bonus["p"]=receiver.p
			record("purchase_buff",bonus)
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
		last_message="Level %d Â· Capacity increased to %d cells" % [tier,capacity()]
	else:
		last_message="+1 XP Â· %d / %d to level %d" % [xp,int(rules.xp_thresholds[tier-1]),tier+1]
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

func preparation_start_health(c):
	# Greed replaces runtime HP; permanent HP survives in the composition.
	# Conversion happens once, before subsequent battle damage/healing.
	return maxf(1.0,constant_of(c,"conversionRate",2)*money) if c.key=="greed_wall" else float(c.max_hp)

var step_lookups_active=false
var lookup_sizes=Vector3i(-1,-1,-1)
var cell_lookup={}
var virus_lookup={}
var core_lookup={}
func prepare_step_lookups():
	# Synchronous update owns array membership. New spawns/offspring change
	# sizes; death only changes the referenced Dictionary, which stays live.
	var sizes=Vector3i(cells.size(),viruses.size(),blood.size())
	if sizes==lookup_sizes:return
	cell_lookup.clear();virus_lookup.clear();core_lookup.clear()
	for c: Dictionary in cells:
		var id=c.id
		# Older numeric checkpoints may contain 1.0; linear equality matches 1.
		if id is float and id==int(id):id=int(id)
		if not cell_lookup.has(id):cell_lookup[id]=c
	for v: Dictionary in viruses:
		var id=v.id
		if id is float and id==int(id):id=int(id)
		if not virus_lookup.has(id):virus_lookup[id]=v
	for b: Dictionary in blood:
		var id=-2-int(b.id)
		if not core_lookup.has(id):core_lookup[id]=b
	lookup_sizes=sizes

func cell_by_id(id):
	if step_lookups_active and id is int:
		prepare_step_lookups()
		return cell_lookup.get(id,{})
	for c in cells:
		if c.id==id:
			return c
	return {}

func endpoint_by_id(id):
	if step_lookups_active and id is int:
		prepare_step_lookups()
		if id < -1:return core_lookup.get(id,{})
		if cell_lookup.has(id):return cell_lookup[id]
		return virus_lookup.get(id,{})
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

# This temporary index is built only during the cell pass; integer IDs are
# required so dictionary lookups use the same equality as the link scan.
var experimental_radar_kernel=null
func prepare_native_radar():
	if not ClassDB.class_exists("CoreKernel"):return {}
	if experimental_radar_kernel==null:experimental_radar_kernel=ClassDB.instantiate("CoreKernel")
	if not experimental_radar_kernel.has_method("radar_last"):return {}
	var ids=[];var indices={};var roots=PackedInt32Array();var edges=PackedInt32Array()
	for c in cells:
		if typeof(c.id)!=TYPE_INT or c.id==-1:return {}
		if not indices.has(c.id):indices[c.id]=ids.size();ids.append(c.id)
		roots.append(indices[c.id])
	for l in links:
		if typeof(l.a)!=TYPE_INT or typeof(l.b)!=TYPE_INT or l.a==-1 or l.b==-1:return {}
		for id in [l.a,l.b]:
			if not indices.has(id):indices[id]=ids.size();ids.append(id)
		edges.append(indices[l.a]);edges.append(indices[l.b])
	var flags=PackedInt32Array()
	for id in ids:
		var ep=endpoint_by_id(id);var provider=cell_by_id(id)
		flags.append((1 if not ep.is_empty() and ep.alive else 0) | (2 if provider.get("key","")=="radar" else 0))
	var last=experimental_radar_kernel.radar_last(flags,edges,roots)
	if last.size()!=cells.size():return {}
	var by_id={}
	for i in range(cells.size()):
		if last[i]>=0:by_id[cells[i].id]=ids[last[i]]
	return {"last":by_id}

func radar_adjacency():
	var adj={}
	for l in links:
		if typeof(l.a)!=TYPE_INT or typeof(l.b)!=TYPE_INT:return {}
		if not adj.has(l.a):adj[l.a]=[]
		adj[l.a].append(l.b)
		if l.a==l.b:continue
		if not adj.has(l.b):adj[l.b]=[]
		adj[l.b].append(l.a)
	return {"edges":adj}

func radar_network(id,adj):
	if typeof(id)!=TYPE_INT or adj.is_empty():return network(id)
	var source=endpoint_by_id(id)
	if source.is_empty() or not source.alive:return []
	var found=[id];var seen={id:true};var cursor=0
	while cursor<found.size():
		var here=found[cursor];cursor+=1
		for other in adj.edges.get(here,[]):
			if other==-1 or seen.has(other):continue
			var c=endpoint_by_id(other)
			if not c.is_empty() and c.alive:
				found.append(other);seen[other]=true
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
	if c.key=="electromagnet": r=float(c.charge)*constant_of(c,"conversionRate",5)*float(rules.scale)
	return r+float(c.get("range_bonus",0))

func speed_of(c):
	return stat_of(c,"speed")

func apply_radar(c, provider={}):
	c["range_bonus"]=(constant_of(provider,"rangeIncrement",20) if not provider.is_empty() else float(rules.radar_bonus))*float(rules.scale)
	c.range_buff=1.0+c.range_bonus/maxf(1,float(catalog[c.key].range)*float(rules.scale))

func interval_of(c):
	if tuning.get(c.key,{}).has("interval"): return float(tuning[c.key].interval)
	var interval=stat_of(c,"interval")
	if c.key=="gatling": return maxf(0.2,interval-constant_of(c,"reduction",0.25)*float(c.get("kills",0)))
	return interval

func make_wave():
	var plan=infection_plan.build(seed_value,round_no,available_virus_keys(),training_mode if training_mode>=0 else 0)
	source_center=Vector2.ZERO
	infection_sources=plan.positions
	source_emitters=plan.emitters
	wave=plan.wave

func begin_battle():
	electricity.reset()
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
		c["participated_round"]=round_no
		c.start=c.p
		c.start_angle=c.angle
		c.cool=0.1
		c.contact=0
		c["friendly_stun"]=0.0
		c["presentation_target"]=-1
		if catalog[c.key].behavior=="seek":preload("res://scripts/seeker_motion.gd").reset(c)
		c.range_buff=1.0
		c["range_bonus"]=0.0
		c.speed_buff=1.0
		c.orbit=c.p.angle()
		c.alive=true
		c.hp=c.max_hp
		c.food=0
		c["bullet_food"]=0
		c["recipe_cool"]=0.0
		c["recipe_pending"]=false
		c["cool_reserve"]=0.0
		if c.key=="tag_sprayer":c["tags"]=int(constant_of(c,"tagAmount",30))
		c["kills"]=0
		c["electric_cool"]=0.0
		c["electric_targets"]={}
		c["distance_charge"]=0.0
		c["distance_health"]=0.0
		c["travel_x"]=c.p.x
		c["travel_y"]=c.p.y
		c.erase("orbit_center");c.erase("orbit_radius")
		if catalog[c.key].behavior=="seek":preload("res://scripts/seeker_motion.gd").reset(c)
		if c.key=="hungry_bomb": c["radius_growth"]=0.0
		c.erase("initial_health_bonus")
		c.erase("initial_conversion_health")
		if c.key=="greed_wall":
			c.hp=preparation_start_health(c)
			c["initial_conversion_health"]=c.hp
		c.charge=int(constant_of(c,"charge",2)) if c.key=="zapper" else 0
	for c in cells:
		for id in network(c.id):
			var n=cell_by_id(id)
			if n.get("key","")=="radar" and ability_reaches(n,c.id): apply_radar(c,n)
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
			var nearest=local.clamp(-physics.half_size(c),physics.half_size(c))
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
	record("heal",{"id":c.id,"hp":c.hp,"p":c.p,"amount":amount,"from":source.get("p",c.p),"source_id":source.get("id",-1)})

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
	if shooter.get("key","")=="gatling": shooter["kills"]=int(shooter.get("kills",0))+1
	particles.append({"kind":"food","p":v.p,"v":Vector2.ZERO,"life":float(rules.protein_lifetime),"r":4.0,"owner":-1})
	effect(v.p,Color("#d4b8e7"),"",20)
	var core=nearest_blood(v.p)
	var key_threat=v.type=="seeker" or v.get("peak_hp",prior_hp)>=3 or (not core.is_empty() and core.p.distance_to(v.p)<80)
	record("virus_defeated",{"type":v.type,"id":v.id,"p":v.p,"key_threat":key_threat})

func push_object(object,offset,kind,origin):
	physics.impulse(self,object,Ref.impulse(offset)*physics.parameter(self,object,"impulse_scale"),origin)
	if offset.length_squared()>0:
		record("pushed",{"id":object.id,"p":object.p,"kind":kind,"from":origin,"direction":offset.normalized()})

func contains_cell(c, p, extra=0.0):
	var local=(p-c.p).rotated(-c.angle)
	if physics.is_box(self,c):
		var half=physics.half_size(c)
		return absf(local.x)<half.x+extra and absf(local.y)<half.y+extra
	return local.length()<physics.radius(c)+extra

func update(delta: float):
	# Keep lookups scoped to this call. Editor/debug changes between ticks
	# (including same-size replacement/reordering) always see fresh membership.
	step_lookups_active=true
	lookup_sizes=Vector3i(-1,-1,-1)
	update_step(delta)
	step_lookups_active=false
	cell_lookup.clear();virus_lookup.clear();core_lookup.clear()

func update_step(delta: float):
	var movement_delta: float=delta
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
	var radar_native=prepare_native_radar() if has_network_buffs else {}
	var radar_edges=radar_adjacency() if has_network_buffs and radar_native.is_empty() else {}
	for c: Dictionary in cells:
		if not c.alive: continue
		c.range_buff=1.0
		c["range_bonus"]=0.0
		c.speed_buff=1.0
		if not radar_native.is_empty():
			if radar_native.last.has(c.id):apply_radar(c,cell_by_id(radar_native.last[c.id]))
		else:
			for id in (radar_network(c.id,radar_edges) if has_network_buffs else []):
				var provider=cell_by_id(id)
				if provider.get("key","")=="radar":
					var safe_ints=not radar_edges.is_empty() and typeof(c.id)==TYPE_INT and typeof(provider.id)==TYPE_INT
					if (provider.id!=c.id if safe_ints else ability_reaches(provider,c.id)):apply_radar(c,provider)
		proteins.tick(self,c,delta)
		if not c.alive:
			if has_network_buffs:
				radar_native=prepare_native_radar()
				radar_edges=radar_adjacency() if radar_native.is_empty() else {}
			continue
		experiments.tick(self,c,delta)
		if interval_of(c)>0:proteins.accelerate_cooldown(c)
		c.cool-=delta
		c.contact=maxf(0,c.contact-delta)
		c["friendly_stun"]=maxf(0,float(c.get("friendly_stun",0))-delta)
		var d: Dictionary=catalog[c.key]
		var velocity: Vector2=Vector2.ZERO
		var reach: float=range_of(c)
		# Only pursuit and a ready aimed shot consume this query. Other abilities
		# use their own area/directional checks; cooldown does not acquire a target.
		var needs_target: bool=d.behavior=="seek" or (d.behavior=="shoot" and c.cool<=0)
		var target: Dictionary=nearest_virus(c.p,reach) if needs_target else {}
		if needs_target and c.key=="tag_splitter":
			var distance=reach if target.is_empty() else c.p.distance_to(target.p)
			for p: Dictionary in particles:
				if p.life>0 and p.kind=="tag" and p.p.distance_to(c.p)<distance:
					target={"p":p.p}
					distance=p.p.distance_to(c.p)
		if needs_target and target.is_empty() and d.category=="T" and reach>0:
			for candidate: Dictionary in viruses:
				if candidate.alive and candidate.tag>0 and c.p.distance_to(candidate.p)<reach*2:
					target=candidate
					break
		if d.behavior=="forward" or d.behavior=="drop":
			velocity=Vector2.RIGHT.rotated(c.angle)*speed_of(c)*Ref.SCALE
		elif d.behavior=="seek":
			# Tagged targets can be detected at twice the normal distance.
			if target.is_empty():
				for v: Dictionary in viruses:
					if v.alive and v.tag>0 and c.p.distance_to(v.p)<reach*2:
						target=v
						break
			velocity=preload("res://scripts/seeker_motion.gd").direction(self,c,target,delta)*speed_of(c)*Ref.SCALE
			var target_id=int(target.get("id",-1))
			if target_id!=int(c.get("presentation_target",-1)):
				var had_target=int(c.get("presentation_target",-1))>=0
				c["presentation_target"]=target_id
				if not had_target or target_id<0:
					record("cell_target",{"id":c.id,"p":c.p,"target_id":target_id,"target":target.get("p",c.p)})
		elif d.behavior=="orbit":
			if not c.has("orbit_center"):
				c["orbit_center"]=reference_core_center()
				c["orbit_radius"]=c.p.distance_to(c.orbit_center)
			var radial: Vector2=c.p-c.orbit_center
			var desired: Vector2=c.orbit_center+radial.normalized().rotated(-PI/100.0)*float(c.orbit_radius)
			velocity=c.p.direction_to(desired)*speed_of(c)*Ref.SCALE
		if c.get("launch_remaining",0.0)>0:
			velocity=Vector2.RIGHT.rotated(c.angle)*150.0
			c.launch_remaining=maxf(0,c.launch_remaining-delta)
		if c.friendly_stun>0: velocity=Vector2.ZERO
		drive_reference_cell(c,velocity*float(c.speed_buff),delta)
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
						if v.alive and v.p.distance_to(c.p)<reach: push_object(v,(v.p-c.p).normalized()*400,"virus",c.p)
					for other: Dictionary in cells:
						if other.id!=c.id and other.alive and other.p.distance_to(c.p)<reach: push_object(other,(other.p-c.p).normalized()*400,"cell",c.p)
				"drop":
					particles.append({"kind":"tag","p":c.p,"v":Vector2.ZERO,"life":1e12,"r":5.0,"owner":c.id})
					record("interferon_created",{"id":c.id,"p":c.p})
				"spray":
					if int(c.get("tags",0))>0:
						c.tags-=1
						var angle=c.angle+rng.randf_range(-PI/2,PI/2)
						particles.append({"kind":"tag","p":c.p,"v":Vector2.from_angle(angle)*95,"life":1e12,"r":5.0,"owner":c.id})
						record("interferon_created",{"id":c.id,"p":c.p})
		if c.key=="magnet":
			for v: Dictionary in viruses:
				if v.alive and v.p.distance_to(c.p)<reach: physics.accelerate(self,v,v.p.direction_to(c.p)*Ref.impulse(1000.0),delta)
	electricity.update(self)
	for c: Dictionary in pending_cells:
		if cells.size()<int(rules.produced_cell_limit): cells.append(c)
	pending_cells.clear()
	var core_positions: PackedVector2Array=[]
	var core_target_names={}
	for b: Dictionary in blood:
		core_positions.append(b.p)
		if typeof(b.id)==TYPE_INT:core_target_names[b.id]="core:"+str(b.id)
	var nearest_cores=PackedInt32Array()
	if supports_batched_cores():
		var virus_positions=PackedVector2Array();var living_cores=PackedInt32Array()
		for v: Dictionary in viruses:virus_positions.append(v.p)
		for b: Dictionary in blood:living_cores.append(int(b.alive))
		nearest_cores=nearest_cores_batch(virus_positions,core_positions,living_cores)
	var motion_contexts={};var default_motion_keys={}
	var swarm_edges=swarm_adjacency()
	for virus_index in range(viruses.size()):
		var v: Dictionary=viruses[virus_index]
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
		var destination: Dictionary=nearest_blood_at(v.p,core_positions) if nearest_cores.is_empty() else (blood[nearest_cores[virus_index]] if nearest_cores[virus_index]>=0 else {})
		if destination.is_empty():
			if gym_mode: continue
			finish(false)
			return
		var target_pos: Vector2=destination.p
		var target_key: String=core_target_names[destination.id] if typeof(destination.id)==TYPE_INT else "core:"+str(destination.id)
		if v.type=="seeker":
			var nearest: float=15.0*26.0/3.5
			for c: Dictionary in cells:
				if not c.alive:continue
				var distance_to_cell: float=c.p.distance_to(v.p)
				if distance_to_cell<nearest:
					target_pos=c.p
					target_key="cell:"+str(c.id)
					nearest=distance_to_cell
		if v.type=="seeker" and v.get("visual_target","")!=target_key:
			record("virus_target",{"id":v.id,"p":v.p,"target":target_pos})
		v.visual_target=target_key
		var dir: Vector2=v.p.direction_to(target_pos)
		var motion_key: String
		if not v.has("physics_diameter"):
			if not default_motion_keys.has(v.type):default_motion_keys[v.type]=physics.material_key(v)
			motion_key=default_motion_keys[v.type]
		else:motion_key=physics.material_key(v)
		if not motion_contexts.has(motion_key):motion_contexts[motion_key]=virus_motion.context(self,v)
		var motion_context: Dictionary=motion_contexts[motion_key]
		v.visual_avoiding=false
		if v.type=="avoider":
			var avoid={};var distance=15.0*26.0/3.5
			for c: Dictionary in cells:
				var d=v.p.distance_to(c.p)
				if c.alive and d<distance:avoid=c;distance=d
			if not avoid.is_empty() and v.freeze<=0:
				var force=avoid.p.direction_to(v.p)*150.0*motion_context.scale*Ref.MASS_UNIT
				virus_motion.apply_impulse(self,v,force*delta,motion_context.mass)
				v.visual_avoiding=true
		if v.type=="swarmer":update_swarm_attraction(v,delta,motion_context,swarm_edges)
		v.visual_heading=dir
		virus_motion.tick(self,v,dir,delta,motion_context)
	physics.step(self,delta)
	join_swarm_contacts()
	for pair: Vector2i in physics.contacts:
		var a=endpoint_by_id(pair.x);var b=endpoint_by_id(pair.y)
		if a.is_empty() or b.is_empty() or a.has("type") or b.has("type"):continue
		for body in [a,b]:
			if body.has("key") and float(body.get("friendly_stun",0))<=0:
				body.friendly_stun=float(rules.get("friendly_collision_stun",0.5))
	for c in cells:
		if c.key=="electric_wall":experiments.electric_contacts(self,c,delta)
	resolve_cell_contacts()
	advance_blasts(delta)
	advance_projectiles(delta,movement_delta)
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
	record("blast_started",{"p":position,"reach":reach,"damage":damage,"duration":duration,"owner":owner})

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
			# Reference 600 / 400 is a one-shot linear impulse, not a force times dt.
			physics.impulse(self,body,blast.p.direction_to(body.p)*Ref.impulse(blast.force),blast.p)
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
		var half=physics.half_size(body)+Vector2.ONE*radius
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

# Bodies do not translate during projectile resolution. Keep array order so
# equal-time hits retain the original cells-before-viruses tie break.
func _prepare_projectile_grid():
	_projectile_grid.clear()
	_projectile_bodies=cells+viruses
	for i in range(_projectile_bodies.size()):
		var p: Vector2=_projectile_bodies[i].p
		var tile=Vector2i(floori(p.x/96.0),floori(p.y/96.0))
		if not _projectile_grid.has(tile):_projectile_grid[tile]=[]
		_projectile_grid[tile].append(i)
	_projectile_grid_active=true

func _clear_projectile_grid():
	_projectile_grid_active=false
	_projectile_grid.clear();_projectile_bodies.clear()

func projectile_candidates(from: Vector2,to: Vector2,radius: float) -> Array:
	if not _projectile_grid_active:return cells+viruses
	# Expanded rotated Wall has half extents (43+r,13+r). This bound
	# includes its corner for every angle, with margin for Float32 rounding.
	var padding=160.0+2.0*absf(radius)
	var lo=Vector2i(floori((minf(from.x,to.x)-padding)/96.0),floori((minf(from.y,to.y)-padding)/96.0))
	var hi=Vector2i(floori((maxf(from.x,to.x)+padding)/96.0),floori((maxf(from.y,to.y)+padding)/96.0))
	if (hi.x-lo.x+1)*(hi.y-lo.y+1)>128:return _projectile_bodies
	var indices=[]
	for y in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			indices.append_array(_projectile_grid.get(Vector2i(x,y),[]))
	indices.sort()
	var found=[]
	for i in indices:found.append(_projectile_bodies[i])
	return found

func resolve_bullet(p,from,to):
	var target={};var nearest=INF
	for body in projectile_candidates(from,to,float(p.r)):
		if not body.alive or body.id==p.owner:continue
		if body.has("type"):
			if body.jump:continue
		elif body.key not in ["bullet_wall","mortar","seeker_factory"]:continue
		elif body.key=="bullet_wall" and p.get("split",false):continue
		elif body.key=="seeker_factory" and not experimental:continue
		var t=projectile_fraction(body,from,to,float(p.r))
		if t<nearest:nearest=t;target=body
	if target.is_empty():return
	apply_bullet_hit(p,from,to,target,nearest)

func apply_bullet_hit(p,from,to,target,nearest):
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
		proteins.consumed(self,target)
		record("protein_eaten",{"id":target.id,"p":target.p,"from":p.p,"kind":"bullet"})

func swarm_adjacency():
	var edges={}
	for link in links:
		if not link.get("swarm",false):continue
		if typeof(link.a)!=TYPE_INT or typeof(link.b)!=TYPE_INT:return {}
		if not edges.has(link.a):edges[link.a]=[]
		edges[link.a].append(link.b)
		if link.a!=link.b:
			if not edges.has(link.b):edges[link.b]=[]
			edges[link.b].append(link.a)
	return {"edges":edges}
func update_swarm_attraction(v,delta,prepared={},swarm_adj={}):
	var host=-1
	if not swarm_adj.is_empty() and typeof(v.id)==TYPE_INT:
		for other in swarm_adj.edges.get(v.id,[]):
			if other==-1:continue
			var body=endpoint_by_id(other)
			if not body.is_empty() and body.alive:host=body.id;break
	else:
		for link in links:
			if not link.get("swarm",false):continue
			var other=link.b if link.a==v.id else (link.a if link.b==v.id else -1)
			if other==-1:continue
			var body=endpoint_by_id(other)
			if not body.is_empty() and body.alive:host=body.id;break
	if v.get("host",-1)!=host:
		record("virus_attachment",{"id":v.id,"p":v.p,"old_host":v.get("host",-1),"host":host})
	v.host=host
	if host!=-1 or v.freeze>0:return
	# Packed scalar sorting avoids invoking a GDScript comparator per pair.
	# Equal keys use the original full sort to preserve its unstable tie order.
	var distances=PackedFloat64Array()
	var by_distance={}
	var tied=false
	var candidates=[]
	for other: Dictionary in viruses:
		if not other.alive or other.id==v.id or other.jump:continue
		var offset: Vector2=v.p-other.p
		if not (offset.length()<60.0*26.0/3.5):continue
		var distance: float=offset.length_squared()
		if by_distance.has(distance):tied=true
		by_distance[distance]=other
		distances.append(distance)
		candidates.append(other)
	var nearby=[]
	if tied:
		for i in range(candidates.size()):nearby.append([distances[i],candidates[i]])
		nearby.sort_custom(func(x,y):return x[0]<y[0])
	else:
		distances.sort()
		for i in range(mini(9,distances.size())):nearby.append([distances[i],by_distance[distances[i]]])
	if nearby.is_empty():return
	# All nine attractions use the same material and movement tuning. Preserve
	# each Vector2 multiply/divide and impulse order, but resolve them once.
	var movement_scale=virus_motion.multiplier(self,v) if prepared.is_empty() else prepared.scale
	var body_mass=physics.mass(self,v) if prepared.is_empty() else prepared.mass
	var body_state=physics.state(v)
	for entry in nearby.slice(0,9):
		var other: Dictionary=entry[1]
		var force: Vector2=v.p.direction_to(other.p)*25.0*movement_scale*Ref.MASS_UNIT
		body_state.v+=force*delta/body_mass

func join_swarm_contacts():
	var contact_grid={}
	var grid_ready=false
	for v in viruses:
		if not v.alive or v.type!="swarmer" or v.jump or v.get("host",-1)>=0:continue
		if not grid_ready:
			# Virus radii are 10: every possible 20.02-unit contact is in
			# this tile or a neighbouring 32-unit tile. Sort original indices
			# to preserve link creation/event order, including multiple joins.
			for i in range(viruses.size()):
				var other: Dictionary=viruses[i]
				if not other.alive or other.jump:continue
				var tile=Vector2i(floori(other.p.x/32.0),floori(other.p.y/32.0))
				if not contact_grid.has(tile):contact_grid[tile]=[]
				contact_grid[tile].append(i)
			grid_ready=true
		var tile=Vector2i(floori(v.p.x/32.0),floori(v.p.y/32.0))
		var candidates=PackedInt32Array()
		for y in range(-1,2):
			for x in range(-1,2):
				for i in contact_grid.get(tile+Vector2i(x,y),[]):candidates.append(i)
		candidates.sort()
		for i in candidates:
			var other: Dictionary=viruses[i]
			if not other.alive or other==v or other.jump:continue
			if v.p.distance_to(other.p)>physics.radius(v)+physics.radius(other)+0.02:continue
			if links.any(func(l):return (l.a==v.id and l.b==other.id) or (l.b==v.id and l.a==other.id)):continue
			links.append({"a":v.id,"b":other.id,"owner":v.id,"rest":v.p.distance_to(other.p),"offset":(other.p-v.p).rotated(-float(v.get("angle",0))),"relative_angle":float(other.get("angle",0))-float(v.get("angle",0)),"locked":true,"swarm":true})
			record("virus_attachment",{"id":v.id,"p":v.p,"old_host":-1,"host":other.id})
			v.host=other.id

func conduct(_c):
	electricity.update(self)

func next_budget():
	return mini(max_funds+int(shop_rules.income),int(shop_rules.max_income))+battle_income

func next_round():
	if phase!="recap": return
	physics.clear()
	blasts.clear()
	cells=cells.filter(func(c):return not c.get("temporary",false))
	links=links.filter(func(l):return not endpoint_by_id(l.a).is_empty() and not endpoint_by_id(l.b).is_empty())
	for c in cells:
		if c.key=="bank" and c.alive and c.get("participated_round",-1)==round_no: c.sale+=int(constant_of(c,"incomeIncrement",1))
		if c.key=="survivor_bomb" and c.alive and c.get("participated_round",-1)==round_no:
			c["radius_growth"]=float(c.get("radius_growth",0))+constant_of(c,"blastIncrement",8)
			record("permanent_growth",{"id":c.id,"p":c.p,"amount":constant_of(c,"blastIncrement",8)})
		c.p=c.start
		c.angle=c.start_angle
		c.range_buff=1.0
		c["range_bonus"]=0.0
		c.hp=c.max_hp
		c.alive=true
		c.erase("initial_health_bonus")
		c.erase("initial_conversion_health")
		c.charge=int(constant_of(c,"charge",2)) if c.key=="zapper" else 0
	rebuild_links()
	for c in cells:
		if catalog[c.key].behavior=="seek":preload("res://scripts/seeker_motion.gd").reset(c)
	# Original TradeHealth processes exchanges sequentially after restoration.
	for c in cells:
		if catalog[c.key].behavior=="seek":preload("res://scripts/seeker_motion.gd").reset(c)
	for c in cells:
		if c.key!="swapper":continue
		var neighbors=ability_targets(c)
		neighbors.sort_custom(func(a,b):
			var da=endpoint_by_id(a).p.distance_squared_to(c.p)
			var db=endpoint_by_id(b).p.distance_squared_to(c.p)
			return a<b if is_equal_approx(da,db) else da<db)
		for id in neighbors:
			var other=cell_by_id(id)
			if other.is_empty():continue
			var before=c.max_hp
			c.max_hp=other.max_hp;c.hp=c.max_hp
			other.max_hp=before;other.hp=before
			c["last_hp_swap"]={"round":round_no+1,"before":before,"after":c.hp,"partner_key":other.key,"partner_before":c.hp,"partner_after":before}
			other["last_hp_swap"]={"round":round_no+1,"before":c.hp,"after":before,"partner_key":c.key,"partner_before":before,"partner_after":c.hp}
			record("swap",{"a":c.id,"b":other.id,"p":c.p,"q":other.p,"before_a":before,"after_a":c.hp,"before_b":c.hp,"after_b":before})
			break
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
	if not physics.is_box(self,c): return physics.radius(c)
	var local=direction.rotated(-c.angle).abs()
	return minf(physics.half_size(c).x/maxf(0.001,local.x),physics.half_size(c).y/maxf(0.001,local.y))

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

func drive_reference_cell(c,target,delta):
	if target.length_squared()==0:return
	var accel=16.0
	if catalog[c.key].behavior=="seek":accel=speed_of(c)*5.0
	var body_state: Dictionary=physics.state(c)
	var velocity: Vector2=body_state.v
	var change: Vector2=target.normalized()*accel*Ref.SCALE*delta
	if (velocity+change).length()>=target.length():
		var axis=velocity.normalized()
		change-=axis*change.dot(axis)
	body_state.v+=change

func reference_core_center():
	var center=Vector2.ZERO
	var count=0
	for core in blood:
		if core.alive:center+=core.p;count+=1
	return center/maxi(1,count)

# Batch only dense tag queries: packing is slower for bullets and sparse fields.
# This selects equivalent implementations, never changes a timestep or event.
func dense_projectile_queries() -> bool:
	var budget=(cells.size()+viruses.size()+particles.size())*8
	var work=0
	for p: Dictionary in particles:
		if p.kind=="tag" and p.life>0:
			work+=viruses.size()
			if work>budget:return true
	return false

func advance_projectiles(delta,movement_delta):
	if particles.is_empty():return
	if physics.web_kernel!=null and dense_projectile_queries() and physics.web_angles_supported(cells):
		advance_projectiles_web(delta,movement_delta)
	else:
		advance_projectiles_native(delta,movement_delta)

func advance_projectiles_native(delta,movement_delta):
	if not particles.is_empty():_prepare_projectile_grid()
	for p: Dictionary in particles:
		if p.life<=0: continue
		p.life-=delta
		var previous=p.p
		if p.kind=="tag":proteins.steer_tag(self,p,delta)
		p.p+=p.v*movement_delta
		if p.kind=="bullet":
			resolve_bullet(p,previous,p.p)
		elif p.kind=="tag":
			proteins.resolve_tag(self,p,previous,p.p)
	_clear_projectile_grid()

func pack_projectile_items(first):
	var packed=PackedFloat64Array()
	for i in range(first,particles.size()):
		var p: Dictionary=particles[i]
		var position: Vector2=p.p;var velocity: Vector2=p.v
		packed.append_array(PackedFloat64Array([1 if p.kind=="bullet" else (2 if p.kind=="tag" else 0),position.x,position.y,velocity.x,velocity.y,p.life,p.r,p.owner,float(p.get("split",false))]))
	return Marshalls.raw_to_base64(packed.to_byte_array())

const PROJECTILE_BODY_KIND={"bullet_wall":2,"mortar":3,"seeker_factory":4,"tag_splitter":5}
func advance_projectiles_web(delta,movement_delta):
	var bodies=[];var packed=PackedFloat64Array()
	for body: Dictionary in cells+viruses:
		var kind=0 if body.has("type") else PROJECTILE_BODY_KIND.get(body.key,-1)
		if kind<0:continue
		bodies.append(body)
		var position: Vector2=body.p
		packed.append_array(PackedFloat64Array([position.x,position.y,body.id,float(body.alive),float(body.get("jump",false)),float(body.get("tag",0)),kind,float(physics.is_box(self,body)),float(body.get("angle",0)),physics.radius(body),physics.half_size(body).x,physics.half_size(body).y]))
	var kernel=physics.web_kernel
	kernel.projectileStart(Marshalls.raw_to_base64(packed.to_byte_array()),pack_projectile_items(0),JSON.stringify([delta,movement_delta,experimental],"",true,true))
	var sent=particles.size();var changed=-1;var alive=0;var tag=0
	while true:
		var extra=pack_projectile_items(sent) if sent<particles.size() else ""
		sent=particles.size()
		var values=JavaScriptBridge.js_buffer_to_packed_byte_array(kernel.projectileNext(changed,alive,tag,extra)).to_float64_array()
		if values.is_empty():break
		changed=-1
		for offset in range(0,values.size(),10):
			var p: Dictionary=particles[int(values[offset])]
			p.p=Vector2(values[offset+1],values[offset+2]);p.v=Vector2(values[offset+3],values[offset+4]);p.life=values[offset+5]
			var target_index=int(values[offset+8])
			if target_index<0:continue
			var target: Dictionary=bodies[target_index]
			var from=Vector2(values[offset+6],values[offset+7])
			if p.kind=="bullet":apply_bullet_hit(p,from,p.p,target,values[offset+9])
			else:proteins.apply_tag_hit(self,p,from,p.p,target,values[offset+9])
			changed=target_index;alive=int(target.alive);tag=int(float(target.get("tag",0))>0)



func nearest_cores_batch(_v: PackedVector2Array,_c: PackedVector2Array,_a: PackedInt32Array) -> PackedInt32Array:
	return PackedInt32Array()

func supports_batched_cores() -> bool:
	return false
