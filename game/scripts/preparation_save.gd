extends RefCounted
# Explicit state contract: no UI, admin files or engine objects in a checkpoint.
const VERSION=2
const FIELDS=["seed_value","round_no","target_rounds","training_mode","experimental","money","tier","xp","frozen","next_id","max_funds","selected_rewards","cells","blood","blood_links","blood_velocity","offers","rewards","reward_choices","particles","source_emitters","infection_sources","source_center","wave","battle_income"]

static func encode(value):
	if value is int:return {"$int":str(value)}
	if value is Vector2: return {"$vec2":[value.x,value.y]}
	if value is Array:
		return value.map(func(item):return encode(item))
	if value is Dictionary:
		var result={}
		for key in value: result[str(key)]=encode(value[key])
		return result
	return value

static func decode(value):
	if value is Array: return value.map(func(item):return decode(item))
	if value is Dictionary:
		if value.size()==1 and value.get("$int") is String and value["$int"].is_valid_int():return int(value["$int"])
		if value.has("$vec2"):
			var p=value["$vec2"]
			if p is Array and p.size()==2 and (p[0] is float or p[0] is int) and (p[1] is float or p[1] is int): return Vector2(p[0],p[1])
		var result={}
		for key in value: result[key]=decode(value[key])
		return result
	return value

static func capture(sim):
	var state={}
	for field in FIELDS: state[field]=encode(sim.get(field))
	state.particles=encode(sim.particles.filter(func(p):return p.get("setup",false)))
	return {"version":VERSION,"state":state,"rng_state":str(sim.rng.state)}

static func inspect(data,sim):
	if not data is Dictionary: return {"error":"The saved preparation is unreadable."}
	if data.get("version",0)!=VERSION: return {"error":"This preparation uses an unsupported save version."}
	if not data.get("state") is Dictionary or not data.get("rng_state") is String or not data.rng_state.is_valid_int(): return {"error":"The saved preparation is incomplete."}
	var state=decode(data.state)
	for field in FIELDS:
		if not state.has(field):return {"error":"The saved preparation is missing: "+field}
	for field in ["cells","blood","blood_links","offers","rewards","reward_choices","particles","source_emitters","infection_sources","wave","selected_rewards"]:
		if not state[field] is Array:return {"error":"Invalid saved list: "+field}
	for field in ["seed_value","round_no","target_rounds","training_mode","money","tier","xp","next_id","max_funds","battle_income"]:
		if not (state[field] is float or state[field] is int):return {"error":"Invalid saved number: "+field}
	if state.tier<1 or state.tier>5 or state.round_no<1 or state.round_no>state.target_rounds or state.training_mode < -1 or state.training_mode>3:return {"error":"Invalid saved round or level."}
	if not state.source_center is Vector2 or not state.blood_velocity is Dictionary:return {"error":"Invalid saved geometry."}
	var ids={}
	for c in state.cells:
		if not c is Dictionary or not sim.catalog.has(c.get("key","")) or not c.get("p") is Vector2 or not c.get("start") is Vector2:return {"error":"This save contains an unknown or invalid cell."}
		for field in ["id","hp","max_hp","rank","sale"]:
			if not (c.get(field) is float or c.get(field) is int):return {"error":"Invalid cell state."}
		if ids.has(c.id) or c.rank<1 or c.rank>3:return {"error":"Invalid cell identity or rank."}
		ids[c.id]=true
	for b in state.blood:
		if not b is Dictionary or not b.get("p") is Vector2 or not b.has("id") or not b.get("alive") is bool:return {"error":"Invalid Core state."}
	for list in [state.offers,state.rewards,state.selected_rewards]:
		for key in list:
			if not sim.catalog.has(key):return {"error":"This save refers to an unavailable cell."}
	for pair in state.reward_choices:
		if not pair is Array or pair.size()!=2:return {"error":"Invalid reward choice."}
		for key in pair:
			if not sim.catalog.has(key):return {"error":"Unknown reward cell."}
	for p in state.infection_sources:
		if not p is Vector2:return {"error":"Invalid Source position."}
	for p in state.particles:
		if not p is Dictionary or not p.get("p") is Vector2 or not p.get("v") is Vector2:return {"error":"Invalid preparation resource."}
	for link in state.blood_links:
		if not link is Dictionary or not link.has("a") or not link.has("b") or int(link.a)<0 or int(link.b)<0 or int(link.a)>=state.blood.size() or int(link.b)>=state.blood.size():return {"error":"Invalid Core connection."}
	for emitter in state.source_emitters:
		if not emitter is Dictionary or not emitter.get("p") is Vector2:return {"error":"Invalid Source."}
		for field in ["lane","amount","cooldown","delay"]:
			if not (emitter.get(field) is int or emitter.get(field) is float):return {"error":"Invalid Source timing."}
	for entry in state.wave:
		if not entry is Dictionary or not entry.get("type") is String or not entry.has("count") or not entry.has("lane"):return {"error":"Invalid wave."}
	return {"state":state,"rng_state":int(data.rng_state)}

static func restore(sim,checked):
	var state=checked.state
	sim.training_mode=int(state.training_mode)
	sim.reset(int(state.seed_value),int(state.target_rounds))
	for field in FIELDS:sim.set(field,state[field])
	# JSON object keys are strings; the Core solver keys velocities by integer ID.
	var velocities={}
	for key in sim.blood_velocity:velocities[int(key)]=sim.blood_velocity[key]
	sim.blood_velocity=velocities
	sim.rng.state=checked.rng_state
	sim.phase="shop"
	sim.rebuild_links()
