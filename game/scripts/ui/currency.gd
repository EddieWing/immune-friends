extends Control
var game
func _ready(): mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta): queue_redraw()
func _draw():
	if game==null: return
	var outline=PackedVector2Array([Vector2(41,8),Vector2(71,8),Vector2(71,42),Vector2(100,106),Vector2(96,121),Vector2(16,121),Vector2(12,106),Vector2(41,42),Vector2(41,8)])
	draw_colored_polygon(outline,Color("#d5edf0bd"))
	draw_polyline(outline,Color("#f0ffff"),2,true)
	draw_line(Vector2(36,8),Vector2(76,8),Color("#e6faff"),4,true)
	var count=game.sim.money
	for i in range(mini(count,18)):
		var row=i/5
		var p=Vector2(29+(i%5)*13+sin(i*2.3)*3,108-row*13)
		var points=PackedVector2Array()
		for j in range(5): points.append(p+Vector2.from_angle(j*TAU/5+i)* (5.0 if j%2==0 else 7.0))
		draw_colored_polygon(points,Color("#edbd67"))
		draw_line(p-Vector2(3,2),p+Vector2(1,-4),Color("#fff0b2"),2,true)
	draw_string(ThemeDB.fallback_font,Vector2(32,139),str(count)+" protein",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#e9ffff"))
