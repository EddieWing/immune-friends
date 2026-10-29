extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var cell=s.make_cell("mint",Vector2(50,0));s.cells=[cell]
	s.spawn_virus({"type":"hungry","lane":0,"p":Vector2.ZERO});var v=s.viruses[0]
	var food={"kind":"food","p":Vector2(5,0),"v":Vector2.ZERO,"life":10.0,"r":4.0,"owner":-1};s.particles=[food]
	s.proteins.route_food(s,1.0/60);s.proteins.route_food(s,1.0/60)
	check(v.hp==2 and cell.food==0 and food.life==0,"MC-029: nearest Hungry consumes once, ally cannot double spend")
	food.life=10;food.p=Vector2(45,0);s.proteins.route_food(s,1.0/60)
	check(v.hp==2 and cell.food==1,"MC-029: nearer ally wins regardless of processing order")
	food.life=10;food.p=Vector2(-60,0);s.proteins.route_food(s,1.0/60)
	check(v.hp==2 and food.life>0 and food.p.x>-60,"MC-029: attracting food does not grant health before consumption")
	v.alive=false;cell.p=Vector2(-55,0);s.proteins.route_food(s,1.0/60)
	check(cell.food==2,"MC-029: dead consumer releases ownership")
	quit(errors)
