extends SceneTree
func _initialize():
	var Simulation=load("res://scripts/simulation.gd")
	for rank in [1,3]:
		for carbons in [0,1,5]:
			var sim=Simulation.new()
			sim.reset(42,12)
			var cell=sim.make_cell("greed_wall",Vector2(200,0))
			cell.rank=rank
			sim.cells=[cell]
			sim.money=carbons
			var permanent=cell.max_hp
			var forecast=sim.preparation_health_bonus(cell)
			assert(forecast==carbons*(4 if rank==3 else 2))
			assert(cell.hp==permanent)
			sim.begin_battle()
			assert(cell.hp==permanent+forecast)
			sim.phase="recap"
			sim.next_round()
			assert(cell.max_hp==permanent and cell.hp==permanent)
	print("PASS: Greed preview matches ordinary/elite battle bonus at 0/1/5 Carbons and expires next preparation")
	quit()
