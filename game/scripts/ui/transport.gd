extends Button
var mode=1
var active=false
func _draw():
	var ink=Color("#264b5c") if not disabled else Color("#8197a1")
	if active: draw_line(Vector2(8,size.y-3),Vector2(size.x-8,size.y-3),Color("#72a781"),3,true)
	if mode==0:
		for x in [19,30]: draw_rect(Rect2(x,12,5,17),ink)
	else:
		var count={1:1,2:2,5:3}[mode]
		var left=(size.x-count*11)/2
		for i in range(count):
			var x=left+i*11
			draw_colored_polygon(PackedVector2Array([Vector2(x,12),Vector2(x+10,20.5),Vector2(x,29)]),ink)
