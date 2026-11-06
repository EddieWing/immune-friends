extends SceneTree
func _initialize():
 var result=preload("res://tests/fixtures/motion_comparison.gd").new().run()
 print(result)
 if not result.passed:push_error("Motion presentation output changed")
 quit(0 if result.passed else 1)
