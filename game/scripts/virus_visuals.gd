extends RefCounted
static func draw(canvas,v):
	var p=v.p
	var color=Color("#b399c6")
	if v.type=="hungry": color=Color("#a68bb8")
	if v.type=="wave": color=Color("#bca4d5")
	if v.type=="seeker": color=Color("#be8fae")
	if v.jump: color=Color("#eee0f5")
	var points=PackedVector2Array()
	for i in range(64):
		var angle=i*TAU/64.0
		var radius=12.0
		match v.type:
			"basic": radius+=2.4*cos(angle*7)
			"wave": radius+=4*sin(angle*3+0.5)
			"jumper": radius+=4*cos(angle+PI/3)
			"hungry": radius+=3*sin(angle)
			"swarmer": radius+=4*cos(angle*3-PI/2)
			"seeker": radius+=4*cos(angle*3)
			"avoider": radius-=7*pow(maxf(0,cos(angle)),4)
		points.append(p+Vector2.from_angle(angle)*radius)
	canvas.draw_colored_polygon(points,color)
	points.append(points[0])
	canvas.draw_polyline(points,color.darkened(0.3),1.5,true)
	var ink=Color("#352337")
	for side in [-1,1]:
		var eye=p+Vector2(side*4,-1)
		canvas.draw_circle(eye,2.1,Color("#fff0cd"))
		canvas.draw_circle(eye+Vector2(-side*0.4,0.3),1.0,ink)
		canvas.draw_line(p+Vector2(side*7,-5),p+Vector2(side*2,-3),ink,1.8,true)
	canvas.draw_arc(p+Vector2(0,7),3.2,PI*1.15,PI*1.85,12,ink,1.5,true)
	if v.tag>0:
		canvas.draw_arc(p,17,0,TAU,24,Color("#f4c5d9"),1.5,true)
	if v.jump:
		canvas.draw_arc(p,20,0,TAU,24,Color("#efdefb"),2,true)
	if v.hp>1: canvas.draw_string(ThemeDB.fallback_font,p+Vector2(12,-9),str(int(v.hp)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#e7efe1"))
