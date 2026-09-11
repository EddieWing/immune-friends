extends Button
var game
var key=""
var index=0
var reward=false
var icon_texture: Texture2D
var category="B"
var elite_ready=false

func _ready():
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	add_theme_stylebox_override("hover",StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
	add_theme_stylebox_override("focus",StyleBoxEmpty.new())

func _draw():
	var center=size*0.5
	var radius=minf(size.x,size.y)*0.43
	var color=Color("#c9dae4")
	if is_hovered(): color=Color("#deebef")
	if elite_ready: color=Color("#f5e2a2")
	if reward: color=Color("#dce7bc")
	draw_circle(center+Vector2(1,3),radius,Color(0.2,0.23,0.25,0.25))
	draw_circle(center,radius,color)
	draw_arc(center,radius,0,TAU,64,Color("#a39c94"),1.5,true)
	if icon_texture: draw_texture_rect(icon_texture,Rect2(center-Vector2(29,29),Vector2(58,58)),false)
	var badge=center+Vector2(-radius*0.72,-radius*0.70)
	draw_circle(badge,13,Color("#e8b745") if not reward else Color("#a4bd75"))
	var font=ThemeDB.fallback_font
	var cost="0" if reward else "2"
	draw_string(font,badge+Vector2(-4,5),cost,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#fffdf4"))
	var pos=center+Vector2(radius*0.72,radius*0.70)
	if category=="B":
		draw_rect(Rect2(pos-Vector2(7,7),Vector2(14,14)),Color("#2867ae"))
	else:
		var points=PackedVector2Array()
		for i in range(5): points.append(pos+Vector2.from_angle(-PI/2+i*TAU/5)*10)
		draw_colored_polygon(points,Color("#7f34a4"))
	if has_focus(): draw_arc(center,radius+3,0,TAU,64,Color("#66573f"),2,true)

func _process(_delta):
	queue_redraw()

func _get_drag_data(_at_position):
	if disabled or game.sim.phase!="shop": return null
	game.cancel_placement()
	var preview=TextureRect.new()
	preview.texture=icon_texture
	preview.custom_minimum_size=Vector2(65,65)
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	return {"kind":"cell_offer","key":key,"index":index,"reward":reward}

