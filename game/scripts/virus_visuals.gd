extends RefCounted
const BODIES=preload("res://assets/ui/virus-composite.svg")
const TYPES=["basic","wave","jumper","hungry","swarmer","seeker","avoider"]
static func draw(canvas,v):
	var p=v.p
	var index=maxi(0,TYPES.find(v.type))
	var hurt=v.get("hurt",false)
	var feeding=v.get("feeding",false)
	var tint=Color(1,1,1,v.get("spawn_alpha",1.0))
	var row=(4 if v.jump else 0)+(2 if hurt else 0)+(1 if feeding else 0)
	canvas.draw_texture_rect_region(BODIES,Rect2(p-Vector2(20,20),Vector2(40,40)),Rect2(index*160,row*160,160,160),tint)
	if not hurt:
		var look=v.get("look",Vector2.ZERO)*1.1
		canvas.draw_texture_rect_region(BODIES,Rect2(p+look-Vector2(20,20),Vector2(40,40)),Rect2(0,1280,160,160),tint)
	if v.get("freeze",0)>0:
		for i in range(6):
			var d=Vector2.from_angle(i*TAU/6)
			canvas.draw_line(p+d*14,p+d*20,Color("#d4f8ff"),2,true)
			canvas.draw_line(p+d*17-d.orthogonal()*3,p+d*17+d.orthogonal()*3,Color("#84cbe8"),1.5,true)
	if v.jump:
		canvas.draw_arc(p,20,0,TAU,24,Color("#efdefb"),2,true)
	if v.hp>1 and not v.get("defer_health",false): canvas.draw_string(ThemeDB.fallback_font,p+Vector2(12,-9),str(int(v.hp)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#e7efe1"))
