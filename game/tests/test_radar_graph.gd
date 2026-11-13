extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize():
	var rng=RandomNumberGenerator.new();rng.seed=902105;var s=Sim.new();s.reset(5,12)
	s.cells.clear();s.viruses.clear();s.links.clear()
	for i in range(24):
		var c=s.make_cell("radar" if i%4==0 else "wall",Vector2(i*20,0));s.cells.append(c)
	var checks=0
	for trial in range(300):
		s.links.clear()
		for c in s.cells:c.alive=rng.randf()>0.15
		for b in s.blood:b.alive=rng.randf()>0.15
		var ids=[]
		for c in s.cells:ids.append(c.id)
		for b in s.blood:ids.append(s.core_endpoint(b))
		for n in range(rng.randi_range(0,75)):
			var a=ids[rng.randi_range(0,ids.size()-1)];var b=ids[rng.randi_range(0,ids.size()-1)]
			if a!=b:s.links.append({"a":a,"b":b})
		if trial%3==0 and not s.links.is_empty():s.links[0].a=float(s.links[0].a)
		var adj=s.radar_adjacency()
		for root in ids:
			if s.network(root)!=s.radar_network(root,adj):
				push_error("Network order mismatch graph %d root %s"%[trial,root]);quit(1);return
		for c in s.cells:
			if not c.alive:continue
			for id in s.network(c.id):
				var p=s.cell_by_id(id)
				if p.get("key","")!="radar":continue
				var old=s.ability_reaches(p,c.id);var safe_ints=not adj.is_empty() and typeof(c.id)==TYPE_INT and typeof(p.id)==TYPE_INT;var new=(p.id!=c.id if safe_ints else old)
				if old!=new:
					print("GRAPHDETAIL ",JSON.stringify({"c":c.id,"p":p.id,"old":old,"new":new,"forward":s.network(c.id),"back":s.network(p.id),"links":s.links}));push_error("Radar mismatch on graph %d from %s to %s"%[trial,c.id,p.id]);quit(1);return
				checks+=1
	print("RADAR_GRAPH_EQUIVALENCE PASS checks=",checks," graphs=300");quit(0)
