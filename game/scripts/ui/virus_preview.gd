extends Control
var kind="basic"
var age=0.0
func _ready(): mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta):
 age+=delta
 queue_redraw()
func _draw():
 draw_set_transform(size*0.5,0,Vector2.ONE*3.2)
 preload("res://scripts/virus_visuals.gd").draw(self,{"p":Vector2.ZERO,"type":kind,"age":age,"jump":kind=="jumper" and fmod(age,3.5)>2.8,"tag":0,"hp":1,"id":0})
 draw_set_transform(Vector2.ZERO)
