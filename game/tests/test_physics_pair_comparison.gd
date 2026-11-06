extends SceneTree
func _initialize():
	var result=preload("res://tests/fixtures/physics_pair_comparison.gd").new().run()
	print("Physics pair comparison: ",result)
	quit(0 if result.passed else 1)
