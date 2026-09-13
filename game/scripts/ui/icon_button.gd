extends Button
var glyph=""
var glyph_font: Font
var glyph_size=30
func _draw():
 var ink=get_theme_color("font_disabled_color" if disabled else "font_color")
 var c=size*0.5
 var r=12.0
 var width=2.2
 if glyph=="⇈":
  for x in [-5.5,5.5]:
   draw_line(c+Vector2(x,11),c+Vector2(x,-10),ink,width,true)
   draw_polyline(PackedVector2Array([c+Vector2(x-4,-5),c+Vector2(x,-10),c+Vector2(x+4,-5)]),ink,width,true)
 elif glyph=="⟳":
  draw_arc(c,r,deg_to_rad(35),deg_to_rad(320),48,ink,width,true)
  var tip=c+Vector2.from_angle(deg_to_rad(320))*r
  draw_polyline(PackedVector2Array([tip+Vector2(-6,-1),tip,tip+Vector2(1,-6)]),ink,width,true)
 elif glyph.begins_with("❄"):
  for i in range(6):
   var direction=Vector2.from_angle(i*TAU/6-PI/2)
   var side=direction.orthogonal()
   draw_line(c,c+direction*r,ink,1.8,true)
   var joint=c+direction*7
   for sign_value in [-1,1]: draw_line(joint,joint+direction*3+side*sign_value*3,ink,1.8,true)
  if glyph!="❄": draw_circle(c+Vector2(15,15),3,Color("#65a27d"))
 elif glyph=="▶":
  draw_colored_polygon(PackedVector2Array([c+Vector2(-7,-12),c+Vector2(13,0),c+Vector2(-7,12)]),ink)
 elif glyph_font:
  var extent=glyph_font.get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,glyph_size)
  var baseline=(size.y-glyph_font.get_height(glyph_size))*0.5+glyph_font.get_ascent(glyph_size)
  draw_string(glyph_font,Vector2((size.x-extent.x)*0.5,baseline),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,glyph_size,ink)
