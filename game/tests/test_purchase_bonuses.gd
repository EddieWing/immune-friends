extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize():
	var s=Sim.new();s.reset(42,12);s.experimental=true;s.money=100;s.tier=5
	var wall=s.make_cell("resonant_wall",Vector2.ZERO);var buffer=s.make_cell("resonant_buffer",Vector2(200,0));s.cells=[wall,buffer]
	var hp=wall.max_hp;s.rewards=["wall"]
	assert(s.purchase(0,Vector2(400,0),true))
	var bought=s.cells[-1]
	assert(wall.max_hp==hp+s.constant_of(wall,"healthIncrement"),"free B reward grows existing wall")
	assert(bought.max_hp==s.stat_of(bought,"hp")+s.constant_of(buffer,"healthIncrement"),"free B reward receives buffer HP")
	s.rewards=["wall"];var old=bought.max_hp
	assert(s.purchase(0,bought.p,true))
	assert(bought.max_hp==old+s.stat_of(bought,"hp")+s.constant_of(buffer,"healthIncrement"),"bonus survives immediate merge")
	hp=wall.max_hp;s.money=0;s.offers=["wall"]
	assert(not s.purchase(0,Vector2.ZERO) and wall.max_hp==hp,"failed purchase grants no bonus")
	print("PASS: free reward bonuses, pre-merge bonus and failed purchase exclusion")
	quit()
