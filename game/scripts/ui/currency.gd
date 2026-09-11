extends Control
var game
func _ready(): mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta): queue_redraw()
func _draw():
	if game==null: return
	var count=game.sim.money
	for i in range(mini(count,12)):
		var p=Vector2(25+i*19,17)
		draw_circle(p+Vector2(1,2),8,Color(0.4,0.3,0.15,0.25))
		draw_circle(p,8,Color("#f5c451"))
		draw_arc(p,6,PI*1.1,PI*1.75,10,Color("#ffe798"),1.2,true)
	if count>12: draw_string(ThemeDB.fallback_font,Vector2(251,22),"+"+str(count-12),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#4a4a44"))

