extends RefCounted
# Presentation only. Values come from the live cell and simulation's own rules.
static func number(value):
	var rounded=snappedf(float(value),0.1)
	return str(int(rounded)) if is_equal_approx(rounded,roundf(rounded)) else str(rounded)
static func lines(sim,cell):
	if cell.is_empty():return []
	var result=["Current HP: "+number(cell.hp),"Permanent HP: "+number(cell.max_hp)]
	if cell.get("temporary",false):result.append("Temporary cell · this infection only")
	if cell.key=="greed_wall":
		if sim.phase=="shop":result.append("Next infection starts at: "+number(sim.preparation_start_health(cell))+" HP (temporary replacement)")
		elif cell.has("initial_conversion_health"):result.append("HP set at infection start: "+number(cell.initial_conversion_health)+" (temporary)")
	if cell.key=="survivor_bomb":
		result.append("Current radius: "+number(sim.range_of(cell)/float(sim.rules.scale)))
		result.append("Permanent radius growth: +"+number(cell.get("radius_growth",0)))
	if cell.key=="bank":result.append("Sale value: "+str(cell.sale)+" Carbons (persistent)")
	if cell.key=="tag_drag":result.append("Tags left: "+str(cell.get("tags",15)))
	if cell.key=="swapper":result.append("Swaps permanent HP with the nearest bonded partner at the next preparation.")
	if cell.get("last_hp_swap") is Dictionary:
		var swap=cell.last_hp_swap
		result.append("Round %d swap: %s → %s HP" % [int(swap.round),number(swap.before),number(swap.after)])
		result.append("Partner %s: %s → %s HP" % [sim.catalog.get(swap.partner_key,{}).get("name",swap.partner_key),number(swap.partner_before),number(swap.partner_after)])
	return result

static func ability(sim,key,rank=1):
	if key=="greed_wall":
		var coefficient=sim.constant_of({"key":key,"rank":rank},"conversionRate",2)
		return "At infection start HP becomes %s × leftover Carbons (minimum 1). Replaces current HP; permanent HP returns in preparation." % number(coefficient)
	return sim.catalog[key].description
