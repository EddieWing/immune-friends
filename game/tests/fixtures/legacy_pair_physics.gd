extends "res://scripts/body_physics.gd"
# Independent browser kernel from 3f8f86f; the native solver is unchanged.
func _init():
	if OS.has_feature("web"):
		JavaScriptBridge.eval(preload("res://tests/fixtures/legacy_pair_kernel.gd").SOURCE,true)
		web_kernel=JavaScriptBridge.get_interface("microcosmContacts")
