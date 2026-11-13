extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Facts=preload("res://scripts/ui/cell_facts.gd")
const Save=preload("res://scripts/preparation_save.gd")
var failures=0
var checks=0
func check(ok: bool, label: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func _initialize():
	# Expected values independently recorded from the original ECS matrix.
	var expected_by_rank={1:[1,2,10,18],3:[1,4,20,36]}
	var funds=[0,1,5,9]
	for rank in [1,3]:
		for index in range(funds.size()):
			for permanent in [1,2,9,20]:
				var sim=Sim.new();sim.reset(42,12)
				var cell=sim.make_cell("greed_wall",Vector2(200,0))
				cell.rank=rank;cell.max_hp=permanent;cell.hp=permanent
				sim.cells=[cell];sim.money=funds[index]
				var expected=expected_by_rank[rank][index]
				check(sim.preparation_start_health(cell)==expected,"Greed forecast must replace permanent HP")
				check(cell.hp==permanent,"Forecast must not mutate preparation")
				var encoded=JSON.stringify(Save.capture(sim))
				var loaded=Sim.new()
				var inspected=Save.inspect(JSON.parse_string(encoded),loaded)
				check(not inspected.has("error"),"Preparation checkpoint valid")
				if inspected.has("error"):continue
				Save.restore(loaded,inspected)
				sim=loaded;cell=sim.cells[0]
				check(cell.max_hp==permanent and cell.hp==permanent,"Checkpoint preserves permanent HP")
				sim.begin_battle()
				check(cell.hp==expected and cell.max_hp==permanent,"Greed conversion matches original runtime matrix")
				check(cell.initial_conversion_health==expected,"UI retains actual initial conversion")
				check("HP set at infection start: %s (temporary)"%Facts.number(expected) in Facts.lines(sim,cell),"Combat card shows replacement, not additive bonus")
				sim.money+=7
				sim.heal(cell,3)
				check(cell.hp==expected+3,"Later health effects are additive to converted value")
				sim.damage_cell(cell,1,false,{"kind":"virus","id":123,"p":Vector2(250,0)})
				check(cell.hp==expected+2 and cell.max_hp==permanent,"Damage leaves permanent HP unchanged")
				check(cell.initial_conversion_health==expected,"Later funds and HP changes do not rewrite initial value")
				sim.phase="recap";sim.next_round()
				check(cell.hp==permanent and cell.max_hp==permanent,"Preparation restores permanent HP")
				check(not cell.has("initial_conversion_health"),"Temporary conversion metadata cleared")
				inspected=Save.inspect(JSON.parse_string(JSON.stringify(Save.capture(sim))),loaded)
				Save.restore(loaded,inspected)
				check(loaded.cells[0].hp==permanent and not loaded.cells[0].has("initial_conversion_health"),"Next checkpoint excludes expired conversion")
	# Negative control: a regular wall does not convert.
	var sim=Sim.new();sim.reset(41,12)
	var wall=sim.make_cell("wall",Vector2.ZERO);wall.hp=9;wall.max_hp=9
	sim.cells=[wall];sim.money=5;sim.begin_battle()
	check(wall.hp==9 and not wall.has("initial_conversion_health"),"Non-Greed cells are unaffected")
	print("Greed replacement: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
