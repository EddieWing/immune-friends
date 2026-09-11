extends Control
var game
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw():
 var ratio=clampf((game.view.scale.x-0.45)/1.05,0,1)
 var ink=Color("#385265")
 var font=ThemeDB.fallback_font
 draw_string(font,Vector2(1,14),"Зум",HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
 draw_style_box(track_style(Color(0.94,0.97,1,0.8)),Rect2(9,30,10,200))
 draw_style_box(track_style(Color("#678fab")),Rect2(9,230-200*ratio,10,200*ratio))
 for tick in range(11):
  var y=230-tick*20
  draw_line(Vector2(24,y),Vector2(31 if tick%5==0 else 28,y),ink,1,true)
 draw_circle(Vector2(14,230-200*ratio),6,Color("#fff5d8"))
 draw_string(font,Vector2(0,252),str(roundi(ratio*100))+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
func track_style(color):
 var box=StyleBoxFlat.new()
 box.bg_color=color
 box.set_corner_radius_all(5)
 return box
