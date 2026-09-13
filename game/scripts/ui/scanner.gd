extends Control
var game
var anchor=Vector2.ZERO
func _process(_delta): queue_redraw()
func _draw():
	if not game or not game.detail_panel.visible or game.modal.visible: return
	var rect=game.detail_panel.get_global_rect()
	var edge=Vector2(rect.end.x if anchor.x>rect.get_center().x else rect.position.x,clampf(anchor.y,rect.position.y+20,rect.end.y-20))
	var elbow=Vector2(edge.x+24*signf(anchor.x-edge.x),edge.y)
	var ink=Color("#e3ffff")
	draw_polyline(PackedVector2Array([anchor,elbow,edge]),Color("#35586a"),3,true)
	draw_polyline(PackedVector2Array([anchor,elbow,edge]),ink,1,true)
	draw_arc(anchor,12,0,TAU,32,ink,1,true)
	draw_circle(anchor,2,ink)
