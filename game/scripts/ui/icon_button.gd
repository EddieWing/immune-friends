extends Button
var glyph=""
var glyph_font: Font
var glyph_size=30
func _draw():
 if not glyph_font: return
 var extent=glyph_font.get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,glyph_size)
 var baseline=(size.y-glyph_font.get_height(glyph_size))*0.5+glyph_font.get_ascent(glyph_size)
 var color=get_theme_color("font_disabled_color" if disabled else "font_color")
 draw_string(glyph_font,Vector2((size.x-extent.x)*0.5,baseline),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,glyph_size,color)
