extends SceneTree
var failures=0
func check(ok,message):
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate()
	game.save_path="user://soft-motion-test-save.json"
	game.settings_path="user://soft-motion-test.cfg"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.view.set_process(false)
	game.enter_gym()
	game.main_menu.hide()
	game.gym_soft_motion_demo()
	check(game.sim.cells.size()==3 and game.sim.links.size()==1,"Preset has one single cell and one real linked pair")
	var sim=game.sim
	var layer=game.view.soft_motion
	layer.update(sim,0.016)
	var c=sim.cells[0]
	c.p+=Vector2(8,0)
	layer.update(sim,0.016)
	check(layer.face_offset(c.id).x<0,"Face lags behind rightward movement")
	check(layer.states[c.id].q.x<0,"Body compresses along acceleration axis")
	var transform=layer.body_transform(c.id,c.p,0,Vector2.ONE)
	check(is_equal_approx(transform.determinant(),1),"Deformation preserves visual area")
	for i in range(180): layer.update(sim,1.0/60)
	check(layer.face_offset(c.id).length()<0.01 and layer.states[c.id].q.length()<0.001,"Springs settle without permanent distortion")
	game.gym_run()
	layer.update(sim,0)
	var cells=sim.cells.duplicate(true)
	var physics=sim.physics.states.duplicate(true)
	var links=sim.links.duplicate(true)
	var rng_state=sim.rng.state
	for i in range(20): layer.update(sim,0.016)
	check(sim.cells==cells and sim.links==links and sim.physics.states==physics and sim.rng.state==rng_state,"Visual updates leave gameplay and RNG unchanged")
	var frozen=layer.states.duplicate(true)
	layer.update(sim,1)
	check(layer.states==frozen,"Paused battle freezes all spring state")
	for i in range(120):
		sim.update(1.0/60)
		layer.update(sim,1.0/60)
	check(layer.states.values().all(func(s): return s.face.is_finite() and s.q.is_finite()),"Real towing stays finite")
	layer.enabled=false
	check(layer.face_offset(c.id)==Vector2.ZERO,"A/B toggle removes cosmetic offsets")
	game.gym_reset_setup()
	layer.enabled=true
	layer.update(sim,0)
	check(layer.states.values().all(func(s): return s.face==Vector2.ZERO),"Reset clears residual motion")
	game.leave_gym()
	check(not layer.enabled and layer.ids.is_empty(),"Preview does not leak into campaign")
	game.queue_free()
	await process_frame
	print("RESULT: soft motion, %d failures" % failures)
	quit(1 if failures else 0)
