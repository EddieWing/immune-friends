extends RefCounted
static func draw(canvas,v):
	var p=v.p
	var color=Color("#b399c6")
	if v.type=="hungry": color=Color("#a68bb8")
	if v.type=="wave": color=Color("#bca4d5")
	if v.type=="seeker": color=Color("#be8fae")
	if v.jump: color=Color("#eee0f5")
	for i in range(7):
		var a=i*TAU/7+v.age*0.15
		canvas.draw_circle(p+Vector2.from_angle(a)*12,3.5,color.darkened(0.15))
	canvas.draw_circle(p,12,color.darkened(0.25))
	canvas.draw_circle(p,10.5,color)
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
