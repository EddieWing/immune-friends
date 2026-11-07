extends RefCounted
const Sim=preload("res://scripts/simulation.gd")
static func run():
	var native=Sim.new();var web=Sim.new()
	native.physics.web_kernel=null
	if web.physics.web_kernel==null:return {"pass":false,"reason":"Browser kernel unavailable"}
	for s in [native,web]:
		s.reset(4253,12);s.gym_mode=true;s.begin_battle();s.spawn_queue.clear()
	var before=web.blood.duplicate(true)
	for tick in range(3):
		native.update(1.0/60);web.update(1.0/60)
	var rest=0.0;var difference=0.0
	for i in range(web.blood.size()):
		rest=maxf(rest,web.blood[i].p.distance_to(before[i].p))
		difference=maxf(difference,web.blood[i].p.distance_to(native.blood[i].p))
	for s in [native,web]:
		s.blood=[];s.blood_links=[];s.physics.clear()
		var wall=s.make_cell("wall",Vector2.ZERO);wall.hp=100;s.cells=[wall]
		s.spawn_virus({"type":"basic","lane":0,"p":Vector2(30,17)})
		s.viruses[0].hp=100;s.physics.state(s.viruses[0]).v=Vector2(20,-100)
	# Exercise the actual packed browser path, variable box extents and friction.
	for tick in range(20):
		native.physics.step(native,1.0/60);web.physics.step(web,1.0/60)
	for i in range(web.cells.size()):
		difference=maxf(difference,web.cells[i].p.distance_to(native.cells[i].p))
		difference=maxf(difference,web.physics.velocity(web.cells[i]).distance_to(native.physics.velocity(native.cells[i])))
	var result={"pass":rest<1 and difference<0.01,"core_rest_displacement":rest,"native_web_max_error":difference}
	print("REFERENCE_BROWSER_CHECK ",JSON.stringify(result))
	return result
