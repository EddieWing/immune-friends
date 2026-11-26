extends RefCounted
# Rasterize labels at their displayed size, rather than magnifying 10px glyphs.
# No simulation state is changed. Keep geometry in viewport pixels for crisp bars.
static func layout(canvas,point,size):
	var transform=canvas.get_viewport().get_final_transform()*canvas.get_global_transform_with_canvas()
	return {'transform':transform,'point':(transform*point).round(),'size':maxi(1,roundi(size*transform.get_scale().abs().y))}
static func text(canvas,font,point,value,size,color):
	var data=layout(canvas,point,size)
	canvas.draw_set_transform_matrix(data.transform.affine_inverse())
	canvas.draw_string(font,data.point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,data.size,color)
	canvas.draw_set_transform(Vector2.ZERO)
static func bar(canvas,point,fraction):
	var data=layout(canvas,point,3)
	var scale=data.transform.get_scale().abs()
	var width=maxi(1,roundi(24*scale.x))
	var height=maxi(1,roundi(3*scale.y))
	var rect=Rect2((data.point-Vector2(width,height)*0.5).round(),Vector2(width,height))
	canvas.draw_set_transform_matrix(data.transform.affine_inverse())
	canvas.draw_rect(rect,Color('#453450'))
	var filled=roundi(width*clampf(fraction,0,1))
	if filled>0:canvas.draw_rect(Rect2(rect.position,Vector2(filled,height)),Color('#cae2b0'))
	canvas.draw_set_transform(Vector2.ZERO)
