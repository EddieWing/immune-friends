extends Control
var game
func _ready(): mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta): queue_redraw()
func _draw():
	var p=Vector2(35,35)
	draw_arc(p,31,-PI/2,PI*1.5,64,Color("#c9c2b7"),3,true)
	var tier=game.sim.tier
	var previous=0 if tier==1 else int(game.sim.rules.xp_thresholds[tier-2])
	var goal=int(game.sim.rules.xp_thresholds[mini(tier-1,3)])
	var progress=1.0 if tier==5 else clampf(float(game.sim.xp-previous)/maxf(1,goal-previous),0,1)
	if progress>0: draw_arc(p,31,-PI/2,-PI/2+TAU*progress,64,Color("#c97e7d"),3,true)
	var steps=maxi(1,goal-previous)
	for i in range(steps):
		draw_circle(p+Vector2.from_angle(-PI/2+i*TAU/steps)*31,2.7,Color("#494b49"))
	var points=PackedVector2Array()
	for i in range(5): points.append(Vector2(0,0)+Vector2.from_angle(-PI/2+i*TAU/5)*12)
	draw_colored_polygon(points,Color("#7f37a0"))
	draw_string(ThemeDB.fallback_font,Vector2(-4,5),str(tier),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)

