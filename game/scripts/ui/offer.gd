extends Button
var modern=false
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
	if modern:
		draw_modern()
		return
	var center=size*0.5
	var radius=minf(size.x,size.y)*0.43
	var color=Color("#c9dae4")
	if is_hovered(): color=Color("#deebef")
	if elite_ready: color=Color("#f5e2a2")
	if reward: color=Color("#dce7bc")
	var puddle=PackedVector2Array()
	for i in range(49):
		var angle=i*TAU/48
		var ripple=1+0.045*sin(angle*3+index)+0.035*cos(angle*5)
		puddle.append(center+Vector2(cos(angle),sin(angle)*0.84)*radius*ripple)
	draw_colored_polygon(puddle,Color(color,0.65))
	draw_polyline(puddle,Color("#eaffffd9"),1.5,true)
	draw_arc(center+Vector2(-5,-2),radius*0.75,PI*1.1,PI*1.55,16,Color("#ffffff90"),2,true)
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


func draw_modern():
	var ink=Color("#f4ecd3") if not disabled else Color("#8d9697")
	var box=StyleBoxFlat.new()
	box.bg_color=Color("#35434b") if not is_hovered() else Color("#52656a")
	box.border_color=Color("#a99a70") if has_focus() else Color("#7f9aa7")
	box.set_border_width_all(1)
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	draw_rect(Rect2(8,8,size.x-16,54),Color("#c6e0ef"))
	if icon_texture:draw_texture_rect(icon_texture,Rect2((size.x-52)/2,9,52,52),false,Color(1,1,1,0.45 if disabled else 1))
	var font=game.symbol_font
	draw_string(font,Vector2(7,80),category+" "+game.sim.catalog[key].name,HORIZONTAL_ALIGNMENT_LEFT,size.x-12,11,ink)
	draw_string(font,Vector2(8,104),"REWARD" if reward else "TIER "+str(int(game.sim.catalog[key].tier)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,ink)
	draw_string(font,Vector2(size.x-28,104),"●"+("0" if reward else "2"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#e4b24b") if not reward else Color("#92d3a6"))
