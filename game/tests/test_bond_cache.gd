extends SceneTree
func _initialize():
	var result=preload("res://tests/bond_cache_checks.gd").run()
	print(("PASS: " if result.ok else "FAIL: ")+result.message)
	quit(0 if result.ok else 1)
