extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func bullet():return {"p":Vector2.ZERO,"v":Vector2(7428,0),"life":4.0,"r":5.0,"owner":-1,"kind":"bullet"}
func _initialize():
	var s=Sim.new();s.reset(42,12)
	for x in [150,75]:s.spawn_virus({"type":"basic","lane":0,"p":Vector2(x,0)})
	var p=bullet();s.resolve_bullet(p,Vector2.ZERO,Vector2(200,0))
	check(s.viruses[0].alive and not s.viruses[1].alive,"MC-011: swept path hits nearest virus regardless of array order")
	var wall=s.make_cell("bullet_wall",Vector2(50,0));wall.angle=PI/2;s.cells=[wall]
	p=bullet();s.resolve_bullet(p,Vector2.ZERO,Vector2(200,0))
	check(s.particles.filter(func(x):return x.kind=="bullet").size()==2 and s.viruses[0].alive,"MC-011: rotated Bullet Wall intercepts first and splits")
	var mortar=s.make_cell("mortar",Vector2(60,0));s.cells=[mortar]
	p=bullet();s.resolve_bullet(p,Vector2.ZERO,Vector2(200,0))
	check(mortar.food==1 and p.life==0,"MC-011: consumer receives real impact")
	p=bullet();s.resolve_bullet(p,Vector2(0,50),Vector2(200,50))
	check(mortar.food==1 and p.life>0,"MC-011: passing outside collider is not eaten")
	quit(errors)
