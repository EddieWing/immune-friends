extends SceneTree
func _initialize():
	var s=load("res://scripts/simulation.gd").new()
	s.reset(812,12)
	s.gym_mode=true
	s.cells.clear()
	for i in range(16):s.cells.append(s.make_cell("wall" if i%3==0 else "turret",Vector2((i%4)*80-120,(i/4)*70-100)))
	s.rebuild_links();s.begin_battle();s.spawn_queue.clear()
	for i in range(60):
		s.spawn_virus({"type":"basic","lane":0})
		var v=s.viruses.back();v.emerging=false;v.p=Vector2((i%10)*50-225,(i/10)*45-120);v.hp=100
	for c in s.cells:c.hp=1000
	var total=0;var peak=0
	for i in range(120):
		var t=Time.get_ticks_usec();s.update(1.0/60);var cost=Time.get_ticks_usec()-t
		total+=cost;peak=maxi(peak,cost)
	print("BENCH tick us mean=",total/120," peak=",peak," bodies=",s.cells.size()+s.viruses.size())
	total=0
	for i in range(120):
		var t=Time.get_ticks_usec();s.physics.step(s,1.0/60);total+=Time.get_ticks_usec()-t
	print("BENCH physics us mean=",total/120)
	quit()
