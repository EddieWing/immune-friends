extends Control
func _ready(): mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw():
 for y in range(18,int(size.y)-8,23):
  draw_line(Vector2(12,y),Vector2(size.x-12,y),Color(0.18,0.35,0.4,0.045),1,true)
