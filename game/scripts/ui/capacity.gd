extends Label
func _draw():
 var center=Vector2(15,size.y*0.5)
 var ink=Color("#354d57")
 for offset in [Vector2(-4,3),Vector2(4,3),Vector2(0,-4)]:
  draw_circle(center+offset,3.2,ink,false,1.4,true)
