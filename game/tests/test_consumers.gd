extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(19,12)
	var far=s.make_cell("tag_splitter",Vector2(90,0))
	var near=s.make_cell("tag_splitter",Vector2.ZERO);s.cells=[far,near]
	var p={"kind":"tag","p":Vector2(-100,0),"v":Vector2.ZERO,"life":10.0,"r":2.0,"owner":-1}
	s.proteins.resolve_tag(s,p,p.p,Vector2(130,0))
	check(near.food==1 and far.food==0 and p.life==0,"nearest crossed body consumes tag independently of cell order")
	p.life=10;p.p=Vector2(0,100)
	s.proteins.resolve_tag(s,p,p.p,p.p)
	check(p.life>0 and near.food==1,"nearby tag is not consumed without body contact")
	near.alive=false;p.p=Vector2(-100,0)
	s.proteins.resolve_tag(s,p,p.p,Vector2(130,0))
	check(far.food==1,"dead consumer cannot intercept tag")
	var accelerator=s.make_cell("accelerator",Vector2.ZERO);s.cells=[accelerator]
	var food={"kind":"food","p":Vector2.ZERO,"life":10.0,"consumer":999}
	s.particles=[food];s.proteins.route_food(s,1.0/60)
	check(accelerator.food==1 and food.life==0,"Accelerator participates in shared food routing")
	food.life=10;accelerator.alive=false;s.proteins.route_food(s,1.0/60)
	check(not food.has("consumer") and food.life>0,"missing target releases ownership")
	quit(errors)
