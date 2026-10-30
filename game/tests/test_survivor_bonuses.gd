extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var bank=s.make_cell("bank",Vector2.ZERO);var bomb=s.make_cell("survivor_bomb",Vector2(100,0));var dead=s.make_cell("bank",Vector2(200,0))
	bank.rank=3;bomb.rank=3;s.cells=[bank,bomb,dead]
	for round in range(2):
		s.begin_battle();dead.alive=false
		var late=s.make_cell("bank",Vector2(300,0));s.cells.append(late)
		s.phase="recap";s.next_round()
		assert(bank.sale==1+(round+1)*s.constant_of(bank,"incomeIncrement"))
		assert(bomb.radius_growth==(round+1)*s.constant_of(bomb,"blastIncrement"))
		assert(dead.sale==1 and late.sale==1,"dead and nonparticipant get no bonus")
		s.cells.erase(late);var value=bank.sale;s.next_round();assert(bank.sale==value,"repeat transition grants nothing")
	print("PASS: two rounds of elite survivor bonuses, participant/death guards and repeat transition")
	quit()
