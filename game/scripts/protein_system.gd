extends RefCounted
# Recipes are card-derived. Unmeasured radii/launch speeds live in assumptions.
func tick(s,c,delta):
	c["recipe_cool"]=maxf(0,float(c.get("recipe_cool",0))-delta)
	if not c.get("recipe_pending",false):return
	c.recipe_pending=false
	if c.recipe_cool>0:return
	if c.key=="generator" and c.food>=s.constant_of(c,"proteinAmount",8):
		c.food-=int(s.constant_of(c,"proteinAmount",8))
		var increment=int(s.constant_of(c,"increment",8));c.charge+=increment
		s.record("generator_charged",{"id":c.id,"p":c.p,"amount":increment})
	if s.experimental and c.key=="hungry_bomb" and c.food>=1:
		c.food-=1;c["radius_growth"]=float(c.get("radius_growth",0))+s.constant_of(c,"blastIncrement",1)
	if s.experimental and c.key=="seeker_factory" and c.food>=1 and c.get("bullet_food",0)>=2:
		c.food-=1;c.bullet_food-=2
		var baby=s.make_cell("seeker",c.p+Vector2.RIGHT.rotated(c.angle)*40)
		baby["temporary"]=true;s.pending_cells.append(baby)
		s.record("produced",{"id":c.id,"p":c.p,"key":"seeker"})
	if c.key not in ["mortar","mint","tag_splitter"]: return
	var cost=4 if c.key=="mortar" else (3 if c.key=="tag_splitter" else int(s.constant_of(c,"proteinAmount",5)))
	if c.food>=cost:
		c.food-=cost
		c.recipe_cool=0.2 if c.key=="mortar" else 0.0
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
		if c.key in ["mint","generator","accelerator"] or (s.experimental and c.key in ["hungry_bomb","seeker_factory"]):consumers.append(c)
	for v in s.viruses:
		if v.alive and v.type=="hungry":consumers.append(v)
	for p in s.particles:
		if p.kind!="food" or p.life<=0:continue
		var chosen={};var distance=INF
		for consumer in consumers:
			var d=consumer.p.distance_to(p.p)
			var reach=(10.0 if consumer.has("type") else 25.0)*26.0/3.5
			if d<reach and d<distance:chosen=consumer;distance=d
		p.erase("consumer")
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
			consumed(s,chosen)
			s.record("generator_fed" if chosen.key=="generator" else "protein_eaten",{"id":chosen.id,"p":chosen.p,"from":p.p,"kind":"food","food":chosen.food})

# Interferon is not attracted: only the first body crossed may consume it.
func resolve_tag(s,p,from,to):
	var target={};var nearest=INF
	for body in s.cells+s.viruses:
		if not body.alive or body.id==p.owner:continue
		if body.has("type"):
			if body.get("jump",false):continue
		elif body.key!="tag_splitter":continue
		var fraction=s.projectile_fraction(body,from,to,float(p.r))
		if fraction<nearest:nearest=fraction;target=body
	if target.is_empty():return
	p.p=from.lerp(to,nearest);p.life=0
	if target.has("type"):
		target.tag=4;target.freeze=1
		s.record("tagged",{"id":target.id,"p":target.p,"from":p.p,"owner":p.owner})
	else:
		target.food+=1
		consumed(s,target)
		s.record("protein_eaten",{"id":target.id,"p":target.p,"from":p.p,"kind":"tag"})

# The reference evaluates its recipe on arrival of an ingredient. A cooldown
# expiring alone must not manufacture a second batch from stored leftovers.
func consumed(s,c):
	c["recipe_pending"]=true
	tick(s,c,0.0)
