extends SceneTree
func _initialize():
	var s=preload("res://scripts/simulation.gd").new();s.reset(4253,12);s.gym_mode=true
	var before=s.blood.duplicate(true)
	s.begin_battle();s.spawn_queue.clear()
	for i in range(3):s.update(1.0/60)
	var shift=0.0
	for i in range(s.blood.size()):shift=maxf(shift,s.blood[i].p.distance_to(before[i].p))
	print("CORE_REST displacement ",shift)
	quit(1 if shift>1 else 0)
