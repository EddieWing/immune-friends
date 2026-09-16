extends RefCounted
# Recipes are card-derived. Unmeasured radii/launch speeds live in assumptions.
func tick(s,c,_delta):
	if c.key not in ["mortar","mint","tag_splitter"]: return
	var wanted="bullet" if c.key=="mortar" else ("tag" if c.key=="tag_splitter" else "food")
	for p in s.particles:
		if p.life<=0 or p.kind!=wanted or p.p.distance_to(c.p)>float(s.rules.recipe_reach): continue
		p.life=0
		c.food+=1
		s.record("protein_eaten",{"id":c.id,"p":c.p,"from":p.p,"kind":wanted})
	var cost=4 if c.key=="mortar" else (3 if c.key=="tag_splitter" else int(s.rules.mint_recipe))
	while c.food>=cost:
		c.food-=cost
		if c.key=="mint":
			s.battle_income+=1
			s.money+=1
			s.effect(c.p,Color("#f3d272"),"+1 Carb",24)
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
		c["tags"]=15
		c["tag_distance"]=0.0
		c["tag_round"]=s.round_no

func drag(s,c,destination):
	var old=c.p
	if c.key=="tag_drag":
		pickup(s,c)
		var spacing=15.0*float(s.rules.scale)
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
