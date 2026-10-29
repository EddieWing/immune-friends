extends RefCounted
# Recipes are card-derived. Unmeasured radii/launch speeds live in assumptions.
func tick(s,c,_delta):
	if c.key not in ["mortar","mint","tag_splitter"]: return
	var wanted="bullet" if c.key=="mortar" else ("tag" if c.key=="tag_splitter" else "food")
	for p in s.particles:
		if wanted in ["bullet","food"] or p.life<=0 or p.kind!=wanted or p.p.distance_to(c.p)>float(s.rules.recipe_reach): continue
		p.life=0
		c.food+=1
		s.record("protein_eaten",{"id":c.id,"p":c.p,"from":p.p,"kind":wanted})
	var cost=4 if c.key=="mortar" else (3 if c.key=="tag_splitter" else int(s.constant_of(c,"proteinAmount",5)))
	while c.food>=cost:
		c.food-=cost
		if c.key=="mint":
			var income=int(s.constant_of(c,"incomeIncrement",1))
			s.battle_income+=income
			s.money+=income
			s.effect(c.p,Color("#f3d272"),"+%d Carb" % income,24)
		elif c.key=="mortar":
			var bomb=s.make_cell("bomb",c.p+Vector2.RIGHT.rotated(c.angle)*45)
			bomb["temporary"]=true
			bomb["launch_remaining"]=0.6
			bomb.angle=c.angle
			s.pending_cells.append(bomb)
			s.record("produced",{"id":c.id,"p":c.p,"key":"bomb"})
		else:
			var clone=s.make_cell("tag_splitter",c.p+Vector2(0,38))
			clone["temporary"]=true
			s.pending_cells.append(clone)
			s.record("produced",{"id":c.id,"p":c.p,"key":"tag_splitter"})

func pickup(s,c):
	if c.key!="tag_drag" or s.phase!="shop": return
	if int(c.get("tag_round",0))!=s.round_no:
		c["tags"]=int(s.constant_of(c,"tagAmount",15))
		c["tag_distance"]=0.0
		c["tag_round"]=s.round_no

func drag(s,c,destination):
	var old=c.p
	if c.key=="tag_drag":
		pickup(s,c)
		var spacing=s.constant_of(c,"dropDistance",15)*float(s.rules.scale)
		var distance=old.distance_to(destination)
		var cursor=spacing-float(c.get("tag_distance",0.0))
		while cursor<=distance and int(c.get("tags",0))>0:
			var p=old.lerp(destination,cursor/maxf(distance,0.001))
			s.particles.append({"kind":"tag","p":p,"v":Vector2.ZERO,"life":8.0,"r":5.0,"owner":c.id,"setup":true})
			c.tags-=1
			cursor+=spacing
		c["tag_distance"]=fmod(float(c.get("tag_distance",0.0))+distance,spacing)
	c.p=destination
	s.rebuild_links()

# Shared Capsid ownership: choose the nearest eligible consumer once per particle.
# This is the food-routing prerequisite for MC-029, not the entire MC-013 recipe port.
func route_food(s,delta):
	var consumers=[]
	for c in s.cells:
		if not c.alive:continue
		if c.key in ["mint","generator"] or (s.experimental and c.key in ["hungry_bomb","seeker_factory"]):consumers.append(c)
	for v in s.viruses:
		if v.alive and v.type=="hungry":consumers.append(v)
	for p in s.particles:
		if p.kind!="food" or p.life<=0:continue
		var chosen={};var distance=INF
		for consumer in consumers:
			var d=consumer.p.distance_to(p.p)
			var reach=(10.0 if consumer.has("type") else 25.0)*26.0/3.5
			if d<reach and d<distance:chosen=consumer;distance=d
		if chosen.is_empty():continue
		p["consumer"]=chosen.id
		if distance>s.physics.radius(chosen):
			p.p=p.p.move_toward(chosen.p,0.75*60.0*(26.0/3.5)*delta)
			continue
		p.life=0
		if chosen.has("type"):
			chosen.hp+=1;chosen.peak_hp=maxf(chosen.get("peak_hp",chosen.hp),chosen.hp)
			s.record("virus_fed",{"id":chosen.id,"p":chosen.p,"from":p.p,"hp":chosen.hp})
		else:
			chosen.food+=1
			s.record("generator_fed" if chosen.key=="generator" else "protein_eaten",{"id":chosen.id,"p":chosen.p,"from":p.p,"kind":"food","food":chosen.food})
