extends SceneTree
func _initialize():
 var result=preload("res://tests/fixtures/attention_comparison.gd").new().run()
 print(result)
 if not result.passed:push_error("Attention output changed")
 quit(0 if result.passed else 1)
